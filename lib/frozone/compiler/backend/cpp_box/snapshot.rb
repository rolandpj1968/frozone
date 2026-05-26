# Box-first load-phase snapshot serializer.
#
# The load phase leaves behind an object GRAPH — constants, class/module
# instance ivars, and class variables, plus everything transitively
# reachable through ivars / array elements / hash entries. To reproduce
# that state in the compiled binary it must be serialized faithfully:
# every distinct object materialized exactly ONCE, with every reference
# (constant slot, ivar, element, hash value) resolving to that one
# materialization. A naive tree walk duplicates shared objects (breaking
# `equal?`), can't represent interior unnamed objects, and loops on
# cycles.
#
# Proper graph serialization, three steps:
#   1. discover  — transitive closure from the roots, interning every
#                  distinct snapshot object by object identity.
#   2. allocate  — one accessor per object, constructing it EMPTY
#                  (`new Array()`, `new Klass()`, `new String(bytes)`).
#                  Aliases (same object under several names) emit a router
#                  that returns the one canonical accessor.
#   3. wire      — a second pass (in __init_static_state__, after all
#                  allocation) that fills references. Doing this after
#                  every object exists makes cycles + forward references
#                  resolve.
#
# Leaf value-types (Integer / Float / Symbol / nil / true / false), class
# / module refs, and Regexp / Proc snapshots are NOT interned — emitted
# inline via Cpp#emit_leaf (intern_int / intern / singleton / &Foo_CLASS
# / inline construct). They're either value-identical when interned
# (Integer/Symbol), singletons (nil/true/false), or rarely-shared.

require_relative 'runtime/universe'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Snapshot
          KernelFn = Runtime::KernelFn
          # leaf_full: array fully built at alloc (int64_t[] table) — no wiring.
          Node = Struct.new(:val, :accessor, :leaf_full, keyword_init: true)

          def initialize(cpp)
            @cpp = cpp
            @by_id  = {}   # object_id => canonical accessor name (no parens)
            @nodes  = []   # [Node] canonical objects, discovery order
            @aliases = []  # [[alias_accessor, canonical_accessor]]
            @anon_seq = 0
          end

          # Register a named root (constant flat-name → value). Returns:
          #   :canonical — this name owns a freshly-interned object
          #   :alias     — object already owned elsewhere; routes to it
          #   :leaf      — not slottable (caller emits inline as before)
          def register_constant(flat, val)
            return :leaf unless slottable?(val)
            name = "k_#{flat}"
            oid = val.object_id
            if (canon = @by_id[oid])
              @aliases << [name, canon]
              :alias
            else
              intern(val, preferred: name)
              :canonical
            end
          end

          # Seed an anonymous root (class/module ivar value, cvar value).
          def register_anon(val)
            intern(val, preferred: nil) if slottable?(val)
            nil
          end

          # C++ reference expression for a value (valid after discovery).
          def ref_expr(val)
            if slottable?(val)
              acc = @by_id[val.object_id] or
                raise Cpp::EmissionError,
                      "snapshot: #{val.class.name.split('::').last} not interned (discovery missed a root/edge)"
              "#{acc}()"
            else
              @cpp.emit_leaf(val)
            end
          end

          # Allocation-phase accessor KernelFns: one per canonical object
          # (construct empty/leaf), plus a router per alias. MUST be called
          # before wire_lines — it decides each array's leaf_full flag (and
          # registers any int64_t[] tables) which wire_lines then reads.
          def alloc_fns
            canon = @nodes.map do |n|
              # Return-by-reference so a (rare) ConstantWrite to a named
              # constant can rebind the storage via `(k_FOO() = val)`,
              # matching the prior ObjectObject-constant accessor shape.
              KernelFn.new(
                name: n.accessor,
                signature: "BasicObject*& #{n.accessor}()",
                body: "static BasicObject* val = static_cast<BasicObject*>(#{alloc_expr(n)}); return val;",
              )
            end
            routers = @aliases.map do |name, target|
              KernelFn.new(
                name: name,
                signature: "BasicObject* #{name}()",
                body: "return #{target}();",
              )
            end
            canon + routers
          end

          # Wire-phase statement lines (into __init_static_state__, after
          # every alloc accessor exists). Fills elements / entries / ivars.
          def wire_lines
            @nodes.flat_map { |n| wire_node(n) }
          end

          # True if this value owns / aliases a snapshot slot (so the
          # emitter's leaf/sentinel accessor builder skips it — the
          # snapshot's alloc_fns emits its accessor instead).
          def slotted?(val)
            slottable?(val) && @by_id.key?(val.object_id)
          end

          private

          # Identity-bearing heap object needing one shared materialization.
          # Excludes leaf value-types, class/module refs, and the
          # inline-emitted Regexp/Proc snapshots.
          def slottable?(val)
            case val
            when Vm::IntegerObject, Vm::FloatObject, Vm::SymbolObject,
                 Vm::NilObject, Vm::TrueObject, Vm::FalseObject,
                 Vm::ClassObject, Vm::ModuleObject, Vm::RegexpObject,
                 Vm::ProcObject
              false
            when Vm::StringObject, Vm::ArrayObject, Vm::HashObject, Vm::ObjectObject
              true
            else
              false
            end
          end

          def intern(val, preferred:)
            oid = val.object_id
            return @by_id[oid] if @by_id.key?(oid)
            acc = preferred || "k_snap_#{@anon_seq += 1}"
            @by_id[oid] = acc
            @nodes << Node.new(val: val, accessor: acc)
            edges_of(val).each { |ref| intern(ref, preferred: nil) if slottable?(ref) }
            acc
          end

          def edges_of(val)
            case val
            when Vm::ArrayObject then val.raw
            when Vm::HashObject  then val.raw.flat_map { |k, v| [k, v] }
            else (val.instance_variables_hash || {}).values
            end
          end

          def alloc_expr(n)
            val = n.val
            case val
            when Vm::StringObject
              "(new String(#{@cpp.cpp_string_literal(val.raw)}, #{val.raw.bytesize}))"
            when Vm::ArrayObject
              # Large Integer-only arrays: build fully from a static table
              # at alloc (no per-element wiring). Elements are leaves, so
              # there's no identity to preserve among them.
              if (built = @cpp.int_array_build_expr(val.raw))
                n.leaf_full = true
                built
              else
                "(new Array())"
              end
            when Vm::HashObject  then "(new Hash())"
            else "(new #{val.class_object.full_name.to_s.gsub('::', '_')}())"
            end
          end

          def wire_node(n)
            val = n.val
            recv = "#{n.accessor}()"
            case val
            when Vm::StringObject then []
            when Vm::ArrayObject
              return [] if n.leaf_full   # fully built at alloc
              arr = "static_cast<Array*>(#{recv})"
              val.raw.filter_map do |e|
                guard("#{n.accessor} element") { "#{arr}->data.push_back(#{ref_expr(e)});" }
              end
            when Vm::HashObject
              h = "static_cast<Hash*>(#{recv})"
              val.raw.filter_map do |k, v|
                guard("#{n.accessor} entry") { "#{h}->op_aset(new Array({#{ref_expr(k)}, #{ref_expr(v)}}));" }
              end
            else
              klass = val.class_object.full_name.to_s.gsub("::", "_")
              tgt = "(*static_cast<#{klass}*>(#{recv}))"
              (val.instance_variables_hash || {}).filter_map do |name, v|
                iv = name.to_s.delete_prefix("@")
                guard("#{n.accessor}.iv_#{iv}") { "#{tgt}.iv_#{iv} = #{ref_expr(v)};" }
              end
            end
          end

          # Run a reference-emitting block; on EmissionError (a value
          # emit_leaf can't render — e.g. a Binding/MatchData ivar) emit a
          # `// skipped` comment instead of crashing the whole gen, matching
          # the old emit_static_iv_assign rescue behaviour.
          def guard(label)
            yield
          rescue Cpp::EmissionError => e
            "// skipped #{label}: #{e.message.gsub('*/', '* /')}"
          end
        end
      end
    end
  end
end
