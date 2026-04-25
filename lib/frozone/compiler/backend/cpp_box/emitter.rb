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

          # Mirrors Frozone::Compiler::CppEmitter#generate signature so the
          # dispatch site in frozone_compile.rb can swap one for the other.
          def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
            @execute_block = execute_block
            @top_level_scope = top_level_scope
            @globals = globals
            @stub_file = stub_file
            @call_surface = collect_call_surface
            emit_header
            emit_namespace_open
            ClassEmitter.emit_runtime(self, call_surface: @call_surface)
            emit_main_object
            emit_namespace_close
            emit_main
            @out
          end

          private

          # Collects the program's universe of called methods. Each entry
          # is [cpp_method_name, ruby_method_name_for_diagnostics] — the
          # ruby_method_name goes into the method_missing message.
          # BasicObject's vtable surface is exactly this set.
          def collect_call_surface
            calls = {}
            walk_calls = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::MethodCall) && node.receiver_node
                # Only methods with an explicit receiver go through the
                # vtable — bare calls dispatch via this->name() inside
                # MainObject.
                cpp_name = ExprEmitter::OP_NAMES[node.name] || "m_#{node.name}"
                calls[cpp_name] ||= node.name.to_s
              end
              node.children.each { |c| walk_calls.call(c) } if node.respond_to?(:children)
            }
            user_methods.each_value { |m| walk_calls.call(m.body) if m.body }
            walk_calls.call(@execute_block) if @execute_block
            calls
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

          # The synthesised `Ruby::MainObject` represents the top-level
          # `self` (the `main` object in MRI). Top-level user methods
          # become virtuals on this class; the execute block becomes
          # `__top_level__()`.
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

          # Top-level user methods live in `top_level_scope.methods_table`.
          # Filter to user code only — exclude core/4.0/, vm/, ast/.
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
