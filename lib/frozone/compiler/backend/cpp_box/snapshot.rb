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

          # Sentinel owner: object reached from ≥2 owning source files, so it
          # (and its whole closure) lives in the shared/global TU rather than
          # any one owner's file. Distinct from an unseen object (absent key)
          # and from a single owner (a flat-name Symbol).
          SHARED = :__shared__

          def initialize(cpp)
            @cpp = cpp
            @by_id  = {}   # object_id => canonical accessor name (no parens)
            @nodes  = []   # [Node] canonical objects, discovery order
            @aliases = []  # [[alias_accessor, canonical_accessor]]
            @owner_of = {} # object_id => owning-file flat-name | SHARED
            @anon_seq = 0
          end

          # Register a named root (constant flat-name → value). Returns:
          #   :canonical — this name owns a freshly-interned object
          #   :alias     — object already owned elsewhere; routes to it
          #   :leaf      — not slottable (caller emits inline as before)
          def register_constant(flat, val, owner: :main)
            return :leaf unless slottable?(val)
            name = "k_#{flat}"
            oid = val.object_id
            if (canon = @by_id[oid])
              @aliases << [name, canon]
              note_owner(val, owner)   # a 2nd file naming it may make it shared
              :alias
            else
              intern(val, preferred: name, owner: owner)
              :canonical
            end
          end

          # Seed an anonymous root (class/module ivar value, cvar value).
          def register_anon(val, owner: :main)
            intern(val, preferred: nil, owner: owner) if slottable?(val)
            nil
          end

          # Owning source file for a value: a flat-name Symbol, SHARED, or nil
          # (leaf / never interned). Valid after discovery.
          def owner_of(val) = @owner_of[val.object_id]

          # Local-vs-shared partition stats (valid after discovery). Predicts
          # the distribution win: `local` objects move to their owning TU,
          # `shared` stay in the global TU.
          def partition_report
            by_owner = @owner_of.values.tally
            shared = by_owner.delete(SHARED) || 0
            { total: @nodes.size, shared: shared, local: by_owner.values.sum,
              owners: by_owner.size, top: by_owner.sort_by { |_, c| -c }.first(8) }
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

          # Wire-phase lines grouped by owning source file, for distributed
          # emission. Keys: owner flat-name (Symbol) | SHARED. Each value:
          #   { lines: [String], structs: Set[String] }
          # `structs` are the class flat-names whose definitions the lines
          # need *complete* (cast targets / constructed types) — for precise
          # per-TU includes, so the per-owner TU never parses full layouts.
          # Element/value references are BasicObject* accessors, so they add
          # nothing.
          def wire_groups
            groups = Hash.new { |h, k| h[k] = { lines: [], structs: Set.new } }
            @nodes.each do |n|
              lines = wire_node(n)
              next if lines.empty?
              g = groups[@owner_of[n.val.object_id]]
              g[:lines].concat(lines)
              lines.each { |l| g[:structs].merge(structs_in(l)) }
            end
            groups
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

          def intern(val, preferred:, owner:)
            oid = val.object_id
            if @by_id.key?(oid)
              note_owner(val, owner)   # revisit: same owner is fine, cross-owner shares
              return @by_id[oid]
            end
            acc = preferred || "k_snap_#{@anon_seq += 1}"
            @by_id[oid] = acc
            @owner_of[oid] = owner
            @nodes << Node.new(val: val, accessor: acc)
            edges_of(val).each { |ref| intern(ref, preferred: nil, owner: owner) if slottable?(ref) }
            acc
          end

          # Record a (re)visit to an already-interned object from `owner`.
          # Unchanged if same owner or already shared; a different owner means
          # the object is reachable from ≥2 files → promote it (and its whole
          # closure) to SHARED.
          def note_owner(val, owner)
            cur = @owner_of[val.object_id]
            return if cur == SHARED || cur == owner
            promote(val)
          end

          # Mark val + everything reachable from it SHARED. The early
          # SHARED return makes this idempotent and cycle-safe (a cyclic
          # shared subgraph stops once every node is marked).
          def promote(val)
            return unless slottable?(val)
            oid = val.object_id
            return if @owner_of[oid] == SHARED
            @owner_of[oid] = SHARED
            edges_of(val).each { |ref| promote(ref) }
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

          # Class structs a generated wire line needs *complete*, derived by
          # scanning the line itself (exact — matches what emit_leaf / cast /
          # construct actually emitted, so e.g. a `k_X()` user-constant ref
          # adds nothing while a `(&X_CLASS)` ref pulls X's eigenclass).
          #   static_cast<T*>  → T          (cast target; BasicObject is base)
          #   new T(           → T          (constructed type)
          #   &X_CLASS         → X_eigenclass (the singleton's static type)
          #   (&_f_i_N)        → Integer    (interned int literal)
          # Floats / Regexps / Procs surface as `new Float(` / `new Regexp(`
          # / `new Proc(` and are caught by the `new T(` scan.
          def structs_in(line)
            return Set.new if line.start_with?("//")   # // skipped <label>
            s = Set.new
            line.scan(/static_cast<(\w+)\*>/) { |(t)| s << t unless t == "BasicObject" }
            line.scan(/\bnew\s+(\w+)\(/)      { |(t)| s << t }
            line.scan(/&(\w+)_CLASS\b/)       { |(t)| s << "#{t}_eigenclass" }
            s << "Integer" if line.include?("_f_i_")
            s
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
