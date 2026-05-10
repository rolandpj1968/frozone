require 'fileutils'
require_relative 'node'

module Frozone
  module Ast
    # Frozone.compile! { execute_phase }
    #
    # Triggers snapshot-based AoT compilation of the settled VM state to Crystal.
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
      CRYSTAL_DIR = File.expand_path('../../../crystal/gen', __dir__)

      attr_reader :block_node

      def initialize(block_node, output_path: nil, aot_mode: false)
        @block_node = block_node
        @output_path = output_path
        @aot_mode = aot_mode
      end

      def children = [@block_node].compact

      def evaluate(context)
        require_relative '../compiler/codegen'

        # Source file of the stub (methods defined here are load-phase scaffolding,
        # not real user code — exclude them from the snapshot).
        # In --aot mode, the file IS the user code — don't exclude it.
        stub_file = @aot_mode ? nil : @block_node&.source_location&.first

        if ENV['FROZONE_TYPE_INFERENCE']
          require_relative '../compiler/type_inference'
          run_type_inference_debug(stub_file)
          return Vm::NilObject::NIL
        end

        if ENV['FROZONE_CPP']
          if ENV['FROZONE_BOX_FIRST']
            require_relative '../compiler/backend/cpp_box/emitter'
            emitter = Frozone::Compiler::Backend::CppBox::Emitter.new
          else
            require_relative '../compiler/cpp_emitter'
            emitter = Frozone::Compiler::CppEmitter.new
          end
          source = emitter.generate(
            execute_block: @block_node,
            top_level_scope: Vm::Core::OBJECT_CLASS,
            globals: Vm::GLOBALS,
            stub_file: stub_file
          )
          backend_subdir = ENV['FROZONE_BOX_FIRST'] ? 'box' : 'legacy'
          cpp_dir = File.expand_path("../../../cpp/gen/#{backend_subdir}", __dir__)
          FileUtils.mkdir_p(cpp_dir)
          src = @block_node&.source_location&.first || $PROGRAM_NAME
          base = File.basename(src.to_s, '.rb')
          # Box-first emitter returns a Hash {stream_name => content}
          # for the TU split (Step 1: :default + :main). Legacy cpp
          # emitter still returns a single String. Handle both.
          if source.is_a?(Hash)
            fixed = {
              base:     "#{base}_base.hpp",
              layouts:  "#{base}_layouts.hpp",
              default:  "#{base}.cpp",
              universe: "#{base}_universe.cpp",
              static:   "#{base}_static.cpp",
              main:     "#{base}_main.cpp",
            }
            # Per-class streams. Two patterns:
            #   `:class_<ClassName>`     → `frozone_class_<ClassName>.cpp`
            #     (TU split, Step 7 from earlier work)
            #   `:class_hpp_<ClassName>` → `class/<ClassName>.hpp`
            #     (layouts.hpp split Stage 2 — project_layouts_split.md;
            #     each class struct lives in its own header)
            stream_to_filename = lambda do |stream|
              return fixed[stream] if fixed.key?(stream)
              s = stream.to_s
              return "class/#{s.sub('class_hpp_', '')}.hpp" if s.start_with?("class_hpp_")
              return "#{base}_#{stream}.cpp" if s.start_with?("class_")
              raise "unknown emit stream: #{stream}"
            end
            written_count = 0
            unchanged_count = 0
            outputs = source.map do |stream, content|
              # Skip empty streams (auto-created via with_stream's
              # ||= but never written to — shouldn't happen but defensive).
              next if content.empty?
              path = File.join(cpp_dir, stream_to_filename.call(stream))
              # Per-class hpps land in cpp/gen/box/class/; ensure
              # the subdir exists before write.
              FileUtils.mkdir_p(File.dirname(path))
              # Atomic write-if-different so unchanged streams keep
              # their mtime → make's incremental rebuild works.
              prev = File.read(path) rescue nil
              if prev == content
                unchanged_count += 1
              else
                File.write(path, content)
                written_count += 1
              end
              [stream, path]
            end.compact.to_h
            $stderr.puts "Frozone.compile! (C++): #{written_count} written, #{unchanged_count} unchanged across #{outputs.size} files"
          else
            output = @output_path || File.join(cpp_dir, "#{base}.cpp")
            File.write(output, source)
            $stderr.puts "Frozone.compile! (C++): wrote #{output}"
          end
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
        scope = Vm::Core::OBJECT_CLASS
        core_markers = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/]

        user_loc = ->(loc) {
          return false if loc.nil?
          file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
          return false if stub_file && file == stub_file
          core_markers.none? { |m| file.include?(m) }
        }

        user_methods = {}
        (scope.methods_table || {}).each do |name, m|
          user_methods[name] = m if m.is_a?(Vm::Method) && user_loc.call(m.source_location)
        end

        user_classes = {}
        collect_debug_classes = ->(s) {
          (s.constants_table || {}).each do |name, val|
            next if %i[BasicObject Object Module Class Kernel].include?(name)
            if val.is_a?(Vm::ModuleObject)
              user_classes[name] = val
              collect_debug_classes.call(val)
            end
          end
        }
        collect_debug_classes.call(scope)

        constants = scope.constants_table&.dup || {}

        tinf = Frozone::Compiler::TypeInference.new(
          user_methods:  user_methods,
          user_classes:  user_classes,
          execute_block: @block_node,
          constants:     constants
        )
        env = tinf.run

        slots = env.slots
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
        src = @block_node&.source_location&.first ||
              Vm::GLOBALS[:"$0"]&.raw ||
              $PROGRAM_NAME
        base = File.basename(src.to_s, '.rb')
        File.join(CRYSTAL_DIR, "#{base}.cr")
      end
    end
  end
end
