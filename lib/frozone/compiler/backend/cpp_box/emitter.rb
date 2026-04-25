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
          attr_reader :cpp

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
            all_classes = Runtime::ALL_CLASSES + build_user_class_defs
            all_eigenclasses = all_classes.map { |k| Runtime.eigenclass_for(k) }.compact
            classes = all_classes + all_eigenclasses
            kernel_fns = Runtime::ALL_KERNEL_FNS + build_user_constant_accessors
            write_header
            write_namespace_open
            ClassEmitter.write_runtime(self, classes: classes, call_surface: @call_surface, kernel_fns: kernel_fns)
            write_main_object
            write_namespace_close
            write_main
            @out
          end

          private

          # Walk top_level_scope.constants_table for every Vm::ClassObject.
          # Skip Universe-seeded names (BasicObject, Object, Integer, Array,
          # etc.) — they have hand-coded backing already.
          UNIVERSE_NAMES = Set.new(Runtime::ALL_CLASSES.map(&:name)).freeze

          def collect_all_classes
            classes = {}
            (@top_level_scope.constants_table || {}).each do |name, val|
              next unless val.is_a?(Vm::ClassObject)
              next if UNIVERSE_NAMES.include?(name.to_s)
              classes[name] = val
            end
            classes
          end

          # Walk constants_table for non-class instance constants whose
          # class is one we're emitting. For each, build a lazy-init
          # accessor (`k_NAME()`).
          def collect_user_constants
            consts = {}
            (@top_level_scope.constants_table || {}).each do |name, val|
              next if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
              next unless val.is_a?(Vm::ObjectObject)
              klass = val.class_object
              next unless klass.is_a?(Vm::ClassObject) && @user_classes.key?(klass.name)
              consts[name] = val
            end
            consts
          end

          def build_user_constant_accessors
            @user_constants.map do |name, val|
              klass_name = val.class_object.name.to_s
              # Re-construct via no-arg ctor — initialize sets ivars from
              # the body. (Constructors that took args originally aren't
              # recoverable from the snapshot — defer.)
              Runtime::KernelFn.new(
                name: "k_#{name}",
                signature: "BasicObject* k_#{name}()",
                body: "static BasicObject* val = new #{klass_name}(); return val;",
              )
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
              # Skip `:new` (handled by ConstantRead-receiver branch
              # in from_method_call).
              if node.is_a?(Ast::MethodCall) && node.name != :new
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
            @user_classes.each_value do |cls|
              (class_methods(cls).keys + eigenclass_methods(cls).keys).uniq.each do |mname|
                next if mname == :initialize
                cpp_name = Cpp.method_name(mname)
                calls[cpp_name] ||= mname.to_s
              end
            end
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
            user_methods = class_methods(cls)
            methods = user_methods.reject { |n, _| n == :initialize }
            init = user_methods[:initialize]
            Runtime::RubyClass.new(
              name: name.to_s,
              parent: parent_name_for(cls),
              ivars: ivars.map { |iv| "BasicObject* iv_#{iv} = nullptr;" },
              members: [%(const char* ruby_class_name() const override { return "#{name}"; })],
              ctor: build_ctor(name, init),
              overrides: methods.each_with_object({}) { |(mname, m), h|
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
          def collect_eigenclass_ivars(cls)
            eigen = cls.eigenclass rescue nil
            return [] unless eigen
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
            eigenclass_methods(cls).each_value { |m| walk.call(m.body) if m.body }
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
            sc.name == :Object || sc.name.nil? ? "Object" : sc.name.to_s
          end

          # Build a ctor spec for a user class. Required params land as
          # `BasicObject* x`; optional params get C++ default-arg syntax
          # (`BasicObject* x = <default_expr>`). Rest/post/kw params are
          # not yet supported in ctors — raise EmissionError so the
          # whole class falls through to a default ctor (callsites that
          # try to instantiate it with args will then fail to compile,
          # which is the right loud signal).
          def build_ctor(class_name, init_method)
            return nil unless init_method
            parts = []
            locals = Set.new
            (init_method.required_params || []).each do |p|
              parts << "BasicObject* #{p}"
              locals << p.to_s
            end
            (init_method.optional_params || []).each do |(p, default_node)|
              default_str = default_node ? @cpp.from_expr(default_node, locals) : "nil_instance()"
              parts << "BasicObject* #{p} = #{default_str}"
              locals << p.to_s
            end
            if init_method.rest_param || (init_method.post_params && !init_method.post_params.empty?) ||
               (init_method.required_kw_params && !init_method.required_kw_params.empty?) ||
               (init_method.optional_kw_params && !init_method.optional_kw_params.empty?) ||
               init_method.kw_rest_param
              raise Cpp::EmissionError, "ctor with rest/post/kw params not yet supported"
            end
            # Block param: add as optional Proc* default-nullptr arg.
            block_name = MethodEmitter.user_block_name(init_method) || "_block"
            if init_method.block_param
              parts << "Proc* #{block_name} = nullptr"
              locals << block_name
            end
            # Pre-declare every other method local up front (mirror
            # unpack_params) so locals first-written inside an `if`
            # branch are visible to sibling branches and to the
            # implicit `return ...` at the bottom.
            body = capture do
              reserved = %w[args kwargs block]
              (init_method.locals || []).each do |name|
                s = name.to_s
                next if s.empty? || locals.include?(s) || reserved.include?(s)
                line "BasicObject* #{s} = nil_instance();"
                locals << s
              end
              ExprEmitter.write_body(self, init_method.body, locals: locals) if init_method.body
            end
            { params: parts, body: body, class_name: class_name.to_s }
          rescue Cpp::EmissionError
            nil
          end

          # Build an override spec for a user method using unpack_params
          # (so rest/block handling matches MethodEmitter). Empty params
          # field means class_emitter doesn't double-emit unpack lines.
          # EmissionError → nil so caller can drop the entry; the slot
          # falls through to BasicObject's method_missing stub at runtime.
          def build_override(method)
            body = capture do
              locals = MethodEmitter.unpack_params(self, method)
              ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
            end
            {
              params: [],
              body: body + "return nil_instance();\n",
            }
          rescue Cpp::EmissionError
            nil
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
              line "Ruby::MainObject mo;"
              line "mo.__top_level__();"
              line "return 0;"
            end
            line "}"
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
