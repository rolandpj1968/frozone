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
# Stage 2 status: emits empty Ruby::MainObject + main(); no method
# bodies yet. Next step: emit user-defined methods as virtuals and
# the execute block as MainObject#__top_level__.

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
            emit_header
            emit_namespace_open
            emit_main_object
            emit_namespace_close
            emit_main
            @out
          end

          private

          def emit_header
            line %(#include "../runtime/box_first.hpp")
            blank
          end

          def emit_namespace_open
            line "namespace Ruby {"
            blank
          end

          def emit_namespace_close
            blank
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
          end

          def emit_user_methods
            user_methods.each do |name, method|
              blank
              MethodEmitter.emit_user_method(self, name, method)
            end
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

          def emit_top_level_body
            # Step 0: just a marker so we can verify __top_level__ ran.
            # Next iteration will walk @execute_block and emit real
            # statements.
            line %(std::fprintf(stderr, "[box-first] __top_level__ ran\\n");)
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
        end
      end
    end
  end
end
