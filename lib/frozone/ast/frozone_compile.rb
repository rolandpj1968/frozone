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
    #   3. Instead, Codegen walks the live VM state (class table, constant
    #      table) and emits Crystal — user-defined methods, settled constants, and
    #      then the block body as the Crystal `main` (execute phase).
    #
    # Stubs should silence the harness entry points (run_benchmark etc.) before
    # requiring the benchmark so the load phase doesn't actually run the benchmark.
    class FrozoneCompile < Node
      CRYSTAL_DIR = File.expand_path('../../../crystal', __dir__)

      def initialize(block_node, output_path: nil, aot_mode: false)
        @block_node  = block_node
        @output_path = output_path
        @aot_mode    = aot_mode
      end

      def evaluate(context)
        require_relative '../compiler/codegen'

        # Source file of the stub (methods defined here are load-phase scaffolding,
        # not real user code — exclude them from the snapshot).
        # In --aot mode, the file IS the user code — don't exclude it.
        stub_file = @aot_mode ? nil : @block_node&.instance_variable_get(:@source_location)&.first

        if ENV['FROZONE_TYPE_INFERENCE']
          require_relative '../compiler/type_inference'
          run_type_inference_debug(stub_file)
          return Vm::NilObject::NIL
        end

        codegen = Frozone::Compiler::Codegen.new
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

      def format_type(ty)
        return ty.inspect unless ty.is_a?(Hash)
        s = ty[:class].to_s
        s += "[#{format_type(ty[:elem])}]"          if ty[:elem]
        s += "[#{format_type(ty[:key])}=>#{format_type(ty[:val])}]" if ty[:key] && ty[:val]
        s
      end

      def run_type_inference_debug(stub_file)
        scope     = Vm::Core::OBJECT_CLASS
        core_markers = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/]

        user_loc = ->(loc) {
          return false if loc.nil?
          file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
          return false if stub_file && file == stub_file
          core_markers.none? { |m| file.include?(m) }
        }

        user_methods = {}
        (scope.instance_variable_get(:@methods_table) || {}).each do |name, m|
          user_methods[name] = m if m.is_a?(Vm::Method) && user_loc.call(m.source_location)
        end

        user_classes = {}
        collect_debug_classes = ->(s) {
          (s.instance_variable_get(:@constants_table) || {}).each do |name, val|
            next if %i[BasicObject Object Module Class Kernel].include?(name)
            if val.is_a?(Vm::ModuleObject)
              user_classes[name] = val
              collect_debug_classes.call(val)
            end
          end
        }
        collect_debug_classes.call(scope)

        constants = scope.instance_variable_get(:@constants_table)&.dup || {}

        tinf = Frozone::Compiler::TypeInference.new(
          user_methods:  user_methods,
          user_classes:  user_classes,
          execute_block: @block_node,
          constants:     constants
        )
        env = tinf.run

        slots = env.instance_variable_get(:@slots)
        $stderr.puts "\n=== TypeInference results (#{slots.size} slots) ==="
        slots.each do |slot, ty|
          next if ty == :unknown
          ty_str = format_type(ty)
          $stderr.puts "  #{slot.inspect} => #{ty_str}"
        end
        $stderr.puts "=== end TypeInference ===\n"
      end

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
