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

require_relative 'class_emitter'
require_relative 'method_emitter'
require_relative 'expr_emitter'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Emitter
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
          # body strings — ExprEmitter writes via line/indented as usual,
          # but the result accumulates into a returned string instead of
          # the main output.
          def capture
            saved_out, saved_indent = @out, @indent
            @out, @indent = +"", 0
            yield
            result = @out
            @out, @indent = saved_out, saved_indent
            result
          end

          def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
            @execute_block = execute_block
            @top_level_scope = top_level_scope
            @globals = globals
            @stub_file = stub_file
            @user_classes = collect_emittable_classes
            @call_surface = collect_call_surface
            classes = Runtime::ALL_CLASSES + build_user_class_defs
            emit_header
            emit_namespace_open
            ClassEmitter.emit_runtime(self, classes: classes, call_surface: @call_surface)
            emit_main_object
            emit_namespace_close
            emit_main
            @out
          end

          # The user class registry — name → Vm::ClassObject. Exposed for
          # ExprEmitter so it can recognise ConstantRead of a user class
          # and emit the right C++ type.
          attr_reader :user_classes

          private

          # Walk top_level_scope.constants_table for classes the spike
          # currently knows how to emit. The eventual model emits every
          # class in the closed-world image (no user-vs-core distinction)
          # with methods accumulated from all sources; for now we restrict
          # to classes that (a) aren't already in Universe's seed, and
          # (b) have at least one user-source method (the only body kind
          # ExprEmitter knows how to compile right now). Reopens of
          # Universe-seeded classes are silently dropped — TODO.
          UNIVERSE_NAMES = Set.new(Runtime::ALL_CLASSES.map(&:name)).freeze

          def collect_emittable_classes
            classes = {}
            (@top_level_scope.constants_table || {}).each do |name, val|
              next unless val.is_a?(Vm::ClassObject)
              next if UNIVERSE_NAMES.include?(name.to_s)
              next unless emittable_class?(val)
              classes[name] = val
            end
            classes
          end

          def emittable_class?(cls)
            user_source_methods(cls).any?
          end

          def user_source_methods(cls)
            top_level_methods = (@top_level_scope.methods_table || {})
            (cls.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method) && user_source?(m.source_location)
              # Filter out methods inherited from Object (they appear in
              # every class's methods_table; we emit them on MainObject).
              top_level_methods[name] != m
            end
          end

          # Collects (cpp_method_name, arity) → ruby_method_name from every
          # MethodCall in the program. Drives BasicObject's universal
          # vtable surface. Calls without a receiver dispatch via
          # `this->name()` inside MainObject — they don't need a slot.
          def collect_call_surface
            calls = {}
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::MethodCall) && node.receiver_node && node.name != :new
                cpp_name = ExprEmitter.method_cpp_name(node.name)
                arity = (node.arg_nodes || []).length
                calls[[cpp_name, arity]] ||= node.name.to_s
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            user_methods.each_value { |m| walk.call(m.body) if m.body }
            @user_classes.each_value do |cls|
              user_source_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            end
            walk.call(@execute_block) if @execute_block
            # Pull in arities from runtime overrides too — Integer's m_plus
            # declares arity 1, so the BasicObject base must too.
            Runtime::ALL_CLASSES.each do |k|
              k.overrides&.each do |cpp_name, spec|
                calls[[cpp_name, spec[:params].length]] ||= cpp_name.sub(/^m_/, '')
              end
            end
            # Also include user-class method DEFINITIONS — their override
            # slots need to exist on BasicObject even if no one calls them
            # via the vtable yet.
            @user_classes.each_value do |cls|
              user_source_methods(cls).each do |mname, m|
                next if mname == :initialize
                cpp_name = ExprEmitter.method_cpp_name(mname)
                arity = (m.required_params || []).length
                calls[[cpp_name, arity]] ||= mname.to_s
              end
            end
            calls
          end

          # Build RubyClass instances from each user Vm::ClassObject.
          def build_user_class_defs
            @user_classes.map { |name, cls| build_user_class_def(name, cls) }
          end

          def build_user_class_def(name, cls)
            ivars = collect_ivars(cls)
            user_methods = user_source_methods(cls)
            methods = user_methods.reject { |n, _| n == :initialize }
            init = user_methods[:initialize]
            Runtime::RubyClass.new(
              name: name.to_s,
              parent: parent_name_for(cls),
              ivars: ivars.map { |iv| "BasicObject* iv_#{iv} = nullptr;" },
              members: [%(const char* ruby_class_name() const override { return "#{name}"; })],
              ctor: build_ctor(name, init),
              overrides: methods.each_with_object({}) { |(mname, m), h|
                h[ExprEmitter.method_cpp_name(mname)] = build_override(m)
              },
            )
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
            user_source_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            ivars
          end

          def parent_name_for(cls)
            sc = cls.superclass
            return "Object" unless sc
            # Map MRI parent names. For now any non-explicit parent → Object.
            sc.name == :Object || sc.name.nil? ? "Object" : sc.name.to_s
          end

          def build_ctor(class_name, init_method)
            return nil unless init_method
            params, locals = MethodEmitter.build_params(init_method)
            body = capture do
              ExprEmitter.emit_body(self, init_method.body, locals: locals) if init_method.body
            end
            { params: params.split(", ").reject(&:empty?), body: body, class_name: class_name.to_s }
          end

          def build_override(method)
            params, locals = MethodEmitter.build_params(method)
            body = capture do
              ExprEmitter.emit_body(self, method.body, locals: locals, last_is_return: true) if method.body
            end
            {
              params: params.split(", ").reject(&:empty?),
              # Trailing nil-return as a safety net for paths that fall
              # through (empty body, statement-only last expression).
              body: body + "return nil_instance();\n",
            }
          end

          def emit_header
            line %(#include "../runtime/box_first.hpp")
            blank
          end

          def emit_namespace_open
            line "namespace Ruby {"
            blank
          end

          def emit_namespace_close
            line "}  // namespace Ruby"
            blank
          end

          def emit_main_object
            line "struct MainObject : Object {"
            indented do
              line %(const char* ruby_class_name() const override { return "MainObject"; })
              emit_user_methods
              blank
              line "void __top_level__() {"
              indented { emit_top_level_body }
              line "}"
            end
            line "};"
            blank
          end

          def emit_user_methods
            user_methods.each do |name, method|
              blank
              MethodEmitter.emit_user_method(self, name, method)
            end
          end

          def emit_top_level_body
            return unless @execute_block
            body = @execute_block.respond_to?(:body) ? @execute_block.body : @execute_block
            ExprEmitter.emit_body(self, body, locals: Set.new)
          end

          def emit_main
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
