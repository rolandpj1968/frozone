# Box-first C++ backend — orchestrator.
#
# Parallel to the mainline `Frozone::Compiler::CppEmitter`. Where mainline
# specialises eagerly and falls back to box on TI failure, this emitter
# inverts the polarity: every value is `Ruby_X*` deriving from
# `RubyObject`, dispatched via C++ virtual methods. TI-driven unboxing
# is the optimisation pass — added later, on top of an always-correct
# baseline.
#
# Selected via `FROZONE_BOX_FIRST=1` (see ast/frozone_compile.rb).
#
# See memory/project_radical_box_first.md for the pinned plan.
#
# Stage 2 status: scaffold only. No emission logic yet.

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
            emit_placeholder_main
            @out
          end

          private

          def emit_header
            line %(#include "../runtime/box_first.hpp")
            line ""
          end

          def emit_placeholder_main
            line "int main() {"
            indented do
              line %(// box-first scaffold — no emission logic yet)
              line "return 0;"
            end
            line "}"
          end
        end
      end
    end
  end
end
