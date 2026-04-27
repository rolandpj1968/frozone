# Box-first C++ backend — orchestrator.
#
# Parallel to the mainline `Frozone::Compiler::CppEmitter`. Where mainline
# specialises eagerly and falls back to box on TI failure, this emitter
# inverts the polarity: every value is `Ruby::X*` deriving from
# `Ruby::BasicObject`, dispatched via C++ virtual methods. TI-driven
# unboxing is the optimisation pass — added later, on top of an
# always-correct baseline.
#
# Selected via `FROZONE_BOX_FIRST=1` (see ast/frozone_compile.rb).
#
# See memory/project_radical_box_first.md for the pinned plan.
#
# Vocab note: methods that mutate the buffer are `write_*`. Pure
# functions producing cpp strings live on `Cpp` (held as `emit.cpp`).

require_relative 'cpp'
require_relative 'class_emitter'
require_relative 'method_emitter'
require_relative 'expr_emitter'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Emitter
          attr_reader :cpp, :top_level_scope, :user_classes, :user_constants

          def initialize
            @out = +""
            @indent = 0
          end

          def write(*strs) = strs.each { |s| @out << s }
          def line(str) = @out << ("  " * @indent) << str << "\n"
          def blank = @out << "\n"

          def indented
            @indent += 1
            yield
            @indent -= 1
          end

          # Run `yield` with output captured to a string buffer (indent
          # reset). Used for rendering method bodies into RubyClass.overrides
          # body strings — writers commit via line/indented as usual,
          # but the result accumulates into a returned string instead of
          # the main output. ensure-restore so a yield that raises
          # (e.g. graceful-degradation EmissionError) doesn't leak the
          # inner buffer into subsequent writes.
          def capture
            saved_out, saved_indent = @out, @indent
            @out, @indent = +"", 0
            yield
            @out
          ensure
            @out, @indent = saved_out, saved_indent
          end

          def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
            @execute_block = execute_block
            @top_level_scope = top_level_scope
            @globals = globals
            @stub_file = stub_file
            @user_classes = collect_all_classes
            @user_constants = collect_user_constants
            @cpp = Cpp.new(user_classes: @user_classes, user_constants: @user_constants)
            @cpp.emit = self
            @call_surface = collect_call_surface
            print_method_def_analysis if ENV['FROZONE_BOX_ANALYSIS'] == '1'
            all_classes = overlay_universe_methods(Runtime::ALL_CLASSES) + build_user_class_defs
            all_eigenclasses = all_classes.map { |k| Runtime.eigenclass_for(k) }.compact
            classes = all_classes + all_eigenclasses
            @class_ids_for_init = classes.each_with_index.to_h { |k, i| [k.name, i] }
            kernel_fns = Runtime::ALL_KERNEL_FNS + build_user_constant_accessors
            write_header
            write_namespace_open
            ClassEmitter.write_runtime(self, classes: classes, call_surface: @call_surface, kernel_fns: kernel_fns) do
              write_static_state_init
              write_main_object
            end
            write_namespace_close
            write_main
            @out
          end

          private

          # Walk top_level_scope.constants_table for every Vm::ClassObject.
          # Skip Universe-seeded names (BasicObject, Object, Integer, Array,
          # etc.) — they have hand-coded backing already.
          UNIVERSE_NAMES = Set.new(Runtime::ALL_CLASSES.map(&:name)).freeze

          # For each Universe class, find its corresponding
          # Vm::ClassObject in constants_table and compile any methods
          # whose cpp_name isn't already in Universe's hand-coded
          # overrides. The hand-coded ones win on conflict (they're
          # specialised to the C++ data structure); core/4.0/'s body
          # fills in the gaps. Same for eigenclass methods.
          def overlay_universe_methods(universe_classes)
            top = @top_level_scope.constants_table || {}
            universe_classes.map do |klass|
              cls = top[klass.name.to_sym]
              next klass unless cls.is_a?(Vm::ClassObject)
              klass.dup.tap do |k|
                k.overrides = overlay_overrides(klass.overrides || {}, class_methods(cls))
                k.eigenclass_overrides = overlay_overrides(klass.eigenclass_overrides || {}, eigenclass_methods(cls))
              end
            end
          end

          def overlay_overrides(existing_overrides, vm_methods)
            merged = existing_overrides.dup
            vm_methods.each do |mname, m|
              cpp_name = Cpp.method_name(mname)
              next if merged.key?(cpp_name)  # Universe wins
              spec = build_override(m)
              merged[cpp_name] = spec if spec
            end
            merged
          end

          # Recursively walk constants_table from top-level. Nested
          # classes (`Parser::Ruby40`) get added with their flattened
          # name (`:Parser_Ruby40`) — matches what path_to_cpp_name
          # produces at call sites. Modules don't emit as structs but
          # we walk through them to find nested classes.
          def collect_all_classes
            classes = {}
            seen = Set.new
            walk = ->(scope, prefix) {
              return if seen.include?(scope.object_id)
              seen << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                flat = prefix ? :"#{prefix}_#{name}" : name
                if val.is_a?(Vm::ClassObject)
                  classes[flat] = val unless UNIVERSE_NAMES.include?(flat.to_s)
                  walk.call(val, flat)
                elsif val.is_a?(Vm::ModuleObject)
                  walk.call(val, flat)
                end
              end
            }
            walk.call(@top_level_scope, nil)
            classes
          end

          # Recursively walk constants_tables for instance constants
          # (not classes/modules — those are user_classes). Both
          # top-level (`STDOUT`) and nested (`Encoding::BINARY`) get
          # collected with flattened names. Each gets a lazy-init
          # accessor `k_<flat>()` later. Skip primitive Vm types
          # (Symbol/Integer/String/etc.) — those emit as literals via
          # emit_vm_value, not as accessors.
          # Vm primitives that emit as literal expressions (intern,
          # new String, etc.) rather than default-constructed objects.
          PRIMITIVE_VM_VALUE_CLASSES = [
            Vm::IntegerObject, Vm::FloatObject, Vm::SymbolObject,
            Vm::StringObject, Vm::NilObject, Vm::TrueObject, Vm::FalseObject,
            Vm::ArrayObject, Vm::HashObject
          ].freeze

          def primitive_vm_value?(val)
            PRIMITIVE_VM_VALUE_CLASSES.any? { |c| val.is_a?(c) }
          end

          # Recursively walk constants_tables for instance constants
          # (not classes/modules — those are user_classes). Both
          # top-level (`STDOUT`) and nested (`Encoding::BINARY`) get
          # collected with flattened names. Each gets an accessor
          # `k_<flat>()` later — primitives emit as literal
          # expressions, ObjectObjects as default-construct + ivar
          # populate from the snapshot.
          def collect_user_constants
            consts = {}
            seen = Set.new
            walk = ->(scope, prefix) {
              return if seen.include?(scope.object_id)
              seen << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                flat = prefix ? :"#{prefix}_#{name}" : name
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  walk.call(val, flat)
                elsif val.is_a?(Vm::ObjectObject)
                  consts[flat] = val
                end
              end
            }
            walk.call(@top_level_scope, nil)
            consts
          end

          def build_user_constant_accessors
            @user_constants.map do |name, val|
              if primitive_vm_value?(val)
                # Primitive — emit_vm_value gives the literal expr.
                # Cached in a static for identity stability + skip
                # re-evaluation cost on subsequent calls.
                expr = (@cpp.emit_vm_value(val) rescue "nil_instance() /* failed: #{$!&.message} */")
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BasicObject* k_#{name}()",
                  body: "static BasicObject* val = #{expr}; return val;",
                )
              else
                # Snapshot ObjectObject — default-construct (no
                # m_initialize call), let __init_static_state__
                # populate ivars from the Vm instance.
                klass_name = val.class_object.full_name.to_s.gsub("::", "_")
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BasicObject* k_#{name}()",
                  body: "static BasicObject* val = new #{klass_name}(); return val;",
                )
              end
            end
          end

          # All Vm::Method instances on the class. Closed-world: we emit
          # bodies for ALL methods regardless of source — when a body
          # contains an AST shape we can't yet handle, build_override
          # rescues the EmissionError and skips just that method (it
          # falls through to method_missing at runtime). The filter that
          # excludes methods aliased into the class via Object inheritance
          # remains — those get emitted on MainObject.
          def class_methods(cls)
            top_level_methods = (@top_level_scope.methods_table || {})
            (cls.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method)
              top_level_methods[name] != m
            end
          end

          # Collects cpp_method_name → ruby_method_name from every
          # MethodCall in the program + every method definition.
          # Drives BasicObject's universal vtable surface. Universal
          # call protocol means one slot per name (signature is
          # always Array*, Hash*, Proc*) — no arity in the key.
          # Calls without a receiver dispatch via `this->name()`
          # inside MainObject — still need a slot.
          def collect_call_surface
            calls = {}
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              # Receiverless calls (`Complex(x)`, `foo(x)`) emit as
              # `this->m_X(...)` and need a slot too — same universal
              # surface, since `this` is some BasicObject*-derived.
              # `:new` lands here too — it's just a method call on the
              # eigenclass singleton (`(&Foo_CLASS)->m_new(...)`).
              if node.is_a?(Ast::MethodCall)
                cpp_name = Cpp.method_name(node.name)
                calls[cpp_name] ||= node.name.to_s
              end
              # AttributeWrite is `obj.foo = x` (or `arr[i] = x`) —
              # routes through m_foo_set / m_aset on the receiver. Slot
              # required just like a regular method call.
              if node.is_a?(Ast::AttributeWrite)
                cpp_name = Cpp.method_name(node.name)
                calls[cpp_name] ||= node.name.to_s
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            user_methods.each_value { |m| walk.call(m.body) if m.body }
            @user_classes.each_value do |cls|
              class_methods(cls).each_value { |m| walk.call(m.body) if m.body }
              eigenclass_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            end
            # Universe-class overlay method bodies (core/4.0/X.rb)
            # also contain calls — walk them so transitive method
            # references seed the universal surface.
            top = @top_level_scope.constants_table || {}
            Runtime::ALL_CLASSES.each do |universe_klass|
              cls = top[universe_klass.name.to_sym]
              next unless cls.is_a?(Vm::ClassObject)
              class_methods(cls).each_value { |m| walk.call(m.body) if m.body }
              eigenclass_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            end
            walk.call(@execute_block) if @execute_block
            # Runtime override slots also exist on BasicObject.
            Runtime::ALL_CLASSES.each do |k|
              k.overrides&.each do |cpp_name, _|
                calls[cpp_name] ||= cpp_name.sub(/^m_/, '')
              end
            end
            # User-class method DEFINITIONS need slots too — both
            # instance methods AND eigenclass (def self.X) methods.
            # Eigenclass slots especially: Class only has BasicObject's
            # universal surface, so without seeding from def-sites the
            # eigenclass overrides have no parent virtual to override.
            # `initialize` is included — it becomes the `m_initialize`
            # override that the auto-generated `m_new` dispatches into.
            @user_classes.each_value do |cls|
              (class_methods(cls).keys + eigenclass_methods(cls).keys).uniq.each do |mname|
                cpp_name = Cpp.method_name(mname)
                calls[cpp_name] ||= mname.to_s
              end
            end
            # Universe classes get a core/4.0/ method overlay too —
            # add those names to the surface so subclass `override`
            # declarations have a base virtual to point at.
            top = @top_level_scope.constants_table || {}
            Runtime::ALL_CLASSES.each do |universe_klass|
              cls = top[universe_klass.name.to_sym]
              next unless cls.is_a?(Vm::ClassObject)
              (class_methods(cls).keys + eigenclass_methods(cls).keys).uniq.each do |mname|
                cpp_name = Cpp.method_name(mname)
                calls[cpp_name] ||= mname.to_s
              end
            end
            # Always need m_new (called by every `.new`) and
            # m_initialize (called by every m_new) on the universal
            # surface, even if user code doesn't directly invoke them.
            calls["m_new"] ||= "new"
            calls["m_initialize"] ||= "initialize"
            calls
          end

          # Build RubyClass instances from each user Vm::ClassObject.
          # Class methods (def self.X, from cls.eigenclass.methods_table)
          # land in `eigenclass_overrides` — Runtime.eigenclass_for picks
          # them up when generating the paired eigenclass.
          def build_user_class_defs
            @user_classes.map { |name, cls| build_user_class_def(name, cls) }
          end

          def build_user_class_def(name, cls)
            ivars = collect_ivars(cls)
            eigen_ivars = collect_eigenclass_ivars(cls)
            Runtime::RubyClass.new(
              name: name.to_s,
              parent: parent_name_for(cls),
              ivars: ivars.map { |iv| "BasicObject* iv_#{iv} = nil_instance();" },
              members: [%(const char* ruby_class_name() const override { return "#{name}"; })],
              # No special ctor — `initialize` becomes a regular
              # `m_initialize` override; eigenclass auto-emits `m_new`
              # that does `new X(); m_initialize(...); return obj;`.
              overrides: class_methods(cls).each_with_object({}) { |(mname, m), h|
                spec = build_override(m)
                h[Cpp.method_name(mname)] = spec if spec
              },
              eigenclass_overrides: eigenclass_methods(cls).each_with_object({}) { |(mname, m), h|
                spec = build_override(m)
                h[Cpp.method_name(mname)] = spec if spec
              },
              eigenclass_ivars: eigen_ivars,
            )
          end

          # `def self.X` bodies referencing `@y` need iv_y declared on
          # the eigenclass struct (singleton ivars on the metaclass).
          # Also scans the ClassObject's actual ivar table — `self.X =`
          # at class-body level sets ivars on the class object itself
          # (which we render as the eigenclass singleton); without
          # this, runtime-set ivars like `@_lex_actions` (via
          # `attr_accessor` setter at class-body level) wouldn't
          # appear in the emitted struct.
          def collect_eigenclass_ivars(cls)
            eigen = cls.eigenclass rescue nil
            return [] unless eigen
            ivars = []
            seen = Set.new
            add = ->(name) {
              s = name.to_s.delete_prefix('@')
              unless seen.include?(s)
                seen << s
                ivars << s
              end
            }
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::InstanceVariableWrite) || node.is_a?(Ast::InstanceVariableRead)
                add.call(node.name)
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            eigenclass_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            (cls.instance_variables_hash || {}).each_key { |k| add.call(k) }
            ivars
          end

          # Walk class.eigenclass.methods_table for `def self.X` entries.
          # Same closed-world policy as class_methods — emit all, let
          # graceful degradation drop the ones we can't compile.
          def eigenclass_methods(cls)
            eigen = cls.eigenclass rescue nil
            return {} unless eigen
            top_level_methods = (@top_level_scope.methods_table || {})
            (eigen.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method)
              top_level_methods[name] != m
            end
          end

          # Walk user-source methods for InstanceVariableWrite/Read —
          # those tell us which ivars to declare.
          def collect_ivars(cls)
            ivars = []
            seen = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::InstanceVariableWrite) || node.is_a?(Ast::InstanceVariableRead)
                stripped = node.name.to_s.delete_prefix('@')
                unless seen.include?(stripped)
                  seen << stripped
                  ivars << stripped
                end
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            class_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            ivars
          end

          def parent_name_for(cls)
            sc = cls.superclass
            return "Object" unless sc
            return "Object" if sc.name == :Object || sc.name.nil?
            # Nested classes (Parser::Lexer) need the flattened parent
            # name (`Parser_Lexer`) so the emitted struct inherits from
            # the right type — leaf-name alone collides across nesting.
            sc.full_name.to_s.gsub("::", "_")
          end

          # Build a ctor spec for a user class. Required params land as
          # `BasicObject* x`; optional params get C++ default-arg syntax
          # (`BasicObject* x = <default_expr>`). Rest/post/kw params are
          # not yet supported in ctors — raise EmissionError so the
          # whole class falls through to a default ctor (callsites that
          # try to instantiate it with args will then fail to compile,
          # which is the right loud signal).
          # Build an override spec for a user method using unpack_params
          # (so rest/block handling matches MethodEmitter). Empty params
          # field means class_emitter doesn't double-emit unpack lines.
          # EmissionError → nil so caller can drop the entry; the slot
          # falls through to BasicObject's method_missing stub at runtime.
          def build_override(method)
            with_method_scope(method) do
              body = capture do
                locals = MethodEmitter.unpack_params(self, method)
                ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
              end
              {
                params: [],
                body: body + "return nil_instance();\n",
              }
            end
          rescue Cpp::EmissionError => e
            log_skip("method", method, e)
            nil
          end

          # Run `yield` with @cpp.method_scope set to the method's
          # lexical scopes; restore after. Constant resolution inside
          # the body uses Ruby-style outward lookup against this scope.
          def with_method_scope(method)
            prev = @cpp.method_scope
            @cpp.method_scope = method.scopes || []
            yield
          ensure
            @cpp.method_scope = prev
          end

          # Emit a one-line debug log when FROZONE_BOX_DEBUG=1 — surfaces
          # which method/ctor/class was dropped and why. Off by default
          # (would otherwise spam ~hundreds of lines per program).
          def log_skip(kind, method, err)
            return unless ENV['FROZONE_BOX_DEBUG'] == '1'
            loc = method.respond_to?(:source_location) ? method.source_location : nil
            $stderr.puts "[box-first] skip #{kind} #{method&.name} @ #{loc}: #{err.message}"
          end

          # Diagnostic pass — count how many classes define each method
          # name. Single-def names are candidates for direct dispatch
          # (no virtual table slot needed); multi-def names need
          # genuine virtual dispatch. Run with FROZONE_BOX_ANALYSIS=1.
          def print_method_def_analysis
            defs_by_name = Hash.new { |h, k| h[k] = [] }
            user_classes_with_universe = Runtime::ALL_CLASSES.map(&:name) + @user_classes.keys.map(&:to_s)
            walked = Set.new
            walk = ->(scope, prefix) {
              return if walked.include?(scope.object_id)
              walked << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                fname = prefix ? "#{prefix}::#{name}" : name.to_s
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  (val.methods_table || {}).each_key { |m| defs_by_name[m] << "#{fname}#" }
                  if val.respond_to?(:eigenclass) && val.eigenclass
                    (val.eigenclass.methods_table || {}).each_key { |m| defs_by_name[m] << "#{fname}." }
                  end
                  walk.call(val, fname)
                end
              end
            }
            walk.call(@top_level_scope, nil)
            single = defs_by_name.select { |_, ds| ds.size == 1 }
            multi  = defs_by_name.select { |_, ds| ds.size > 1 }
            total  = defs_by_name.size
            $stderr.puts "[box-first analysis]"
            $stderr.puts "  total method names:  #{total}"
            $stderr.puts "  single-def:          #{single.size} (#{(single.size * 100.0 / total).round(1)}%)"
            $stderr.puts "  multi-def:           #{multi.size} (#{(multi.size * 100.0 / total).round(1)}%)"
            $stderr.puts ""
            $stderr.puts "  multi-def histogram (count of names by # of defining classes):"
            buckets = Hash.new(0)
            multi.each_value { |ds| buckets[ds.size] += 1 }
            buckets.sort.each { |n, count| $stderr.puts "    #{n.to_s.rjust(4)} classes: #{count} method names" }
            $stderr.puts ""
            $stderr.puts "  top multi-def methods:"
            multi.sort_by { |_, ds| -ds.size }.first(15).each do |name, ds|
              $stderr.puts "    #{ds.size.to_s.rjust(4)}  :#{name}"
            end
          end

          def write_header
            line %(#include "../runtime/box_first.hpp")
            blank
          end

          def write_namespace_open
            line "namespace Ruby {"
            blank
          end

          def write_namespace_close
            line "}  // namespace Ruby"
            blank
          end

          def write_main_object
            line "struct MainObject : Object {"
            indented do
              line %(const char* ruby_class_name() const override { return "MainObject"; })
              write_user_methods
              blank
              line "void __top_level__() {"
              indented { write_top_level_body }
              line "}"
            end
            line "};"
            blank
          end

          def write_user_methods
            user_methods.each do |name, method|
              blank
              MethodEmitter.write_user_method(self, name, method)
            end
          end

          def write_top_level_body
            return unless @execute_block
            body = @execute_block.respond_to?(:body) ? @execute_block.body : @execute_block
            ExprEmitter.write_body(self, body, locals: Set.new)
          end

          def write_main
            line "int main() {"
            indented do
              line "FROZONE_GC_INIT();"
              line "Ruby::__init_static_state__();"
              line "Ruby::MainObject mo;"
              line "mo.__top_level__();"
              line "return 0;"
            end
            line "}"
          end

          # Materialise every reachable Vm value that exists at AOT
          # time but isn't a literal in the program:
          #   - ClassObject ivars (set via `self.X = ...` at class-body
          #     level — the ragel-generated lexer tables are the
          #     canonical case)
          #   - Nested user-constants' ivars (e.g. `Encoding::BINARY`
          #     has @name = "ASCII-8BIT" etc.)
          # Failures (unsupported value type, unresolved class) skip
          # that one ivar with a comment.
          def write_static_state_init
            line "void __init_static_state__() {"
            indented do
              # Eigenclass singleton class-id population — drives
              # is_a?'s LUT lookup. Also goes via static state init
              # (singletons are constructed before main; we're just
              # filling the field after that).
              (@class_ids_for_init || {}).each do |flat_name, cid|
                # All emitted classes have a paired _CLASS singleton
                # (eigenclass_for is called for every entry). Skip
                # plain instance classes — their ids end up on the
                # eigenclass via instance_class_id_.
                next if flat_name.end_with?("_eigenclass")
                line "#{flat_name}_CLASS.instance_class_id_ = #{cid};"
              end
              @user_classes.each do |flat, cls|
                (cls.instance_variables_hash || {}).each do |name, val|
                  emit_static_iv_assign("#{flat}_CLASS", flat, name, val)
                end
              end
              @user_constants.each do |flat, obj|
                next if primitive_vm_value?(obj)  # literals have no ivars
                klass = obj.class_object.full_name.to_s.gsub("::", "_")
                target = "(*static_cast<#{klass}*>(k_#{flat}()))"
                (obj.instance_variables_hash || {}).each do |name, val|
                  emit_static_iv_assign(target, flat, name, val)
                end
              end
            end
            line "}"
            blank
          end

          def emit_static_iv_assign(target_expr, label, ivar_name, val)
            iv = ivar_name.to_s.delete_prefix('@')
            expr = @cpp.emit_vm_value(val)
            line "#{target_expr}.iv_#{iv} = #{expr};"
          rescue Cpp::EmissionError => e
            line "// skipped #{label}.iv_#{iv}: #{e.message.gsub('*/', '* /')}"
            $stderr.puts "[box-first] skip static-init #{label}.iv_#{iv}: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
          end

          # Top-level user methods (not on a class).
          def user_methods
            (@top_level_scope.methods_table || {}).select do |_, m|
              m.is_a?(Vm::Method) && user_source?(m.source_location)
            end
          end

          CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

          def user_source?(loc)
            return false if loc.nil?
            file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
            return false if @stub_file && file == @stub_file
            CORE_PATH_MARKERS.none? { |m| file.include?(m) }
          end
        end
      end
    end
  end
end
