require_relative 'node'

module Frozone
  module Ast
    # Frozone.compile! { execute_phase }
    #
    # Triggers snapshot-based AOT compilation of the settled VM state to Crystal.
    #
    # Workflow:
    #   1. The interpreter runs the load phase normally (class defs, constants settle).
    #   2. When Frozone.compile! is reached, the block is NOT evaluated.
    #   3. Instead, SnapshotCodegen walks the live VM state (class table, constant
    #      table) and emits Crystal — user-defined methods, settled constants, and
    #      then the block body as the Crystal `main` (execute phase).
    #
    # Stubs should silence the harness entry points (run_benchmark etc.) before
    # requiring the benchmark so the load phase doesn't actually run the benchmark.
    class FrozoneCompile < Node
      CRYSTAL_DIR = File.expand_path('../../../crystal', __dir__)

      def initialize(block_node, output_path: nil)
        @block_node  = block_node
        @output_path = output_path
      end

      def evaluate(context)
        require_relative '../compiler/snapshot_codegen'

        # Source file of the stub (methods defined here are load-phase scaffolding,
        # not real user code — exclude them from the snapshot).
        stub_file = @block_node&.instance_variable_get(:@source_location)&.first

        codegen = Frozone::Compiler::SnapshotCodegen.new
        crystal_source = codegen.generate(
          execute_block: @block_node,
          top_level_scope: Vm::Core::OBJECT_CLASS,
          globals: Vm::GLOBALS,
          stub_file: stub_file
        )

        output = @output_path || default_output_path
        File.write(output, crystal_source)
        $stderr.puts "Frozone.compile!: wrote #{output}"

        Vm::NilObject::NIL
      end

      private

      def default_output_path
        # Prefer the block's source file (the stub path) over $PROGRAM_NAME
        # (which is frozone.rb — the interpreter, not the script).
        src = @block_node&.instance_variable_get(:@source_location)&.first ||
              Vm::GLOBALS[:"$0"]&.raw ||
              $PROGRAM_NAME
        base = File.basename(src.to_s, '.rb')
        File.join(CRYSTAL_DIR, "#{base}.cr")
      end
    end
  end
end
