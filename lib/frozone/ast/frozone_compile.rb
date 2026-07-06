require 'fileutils'
require_relative 'node'

module Frozone
  module Ast
    # Frozone.compile! { execute_phase }
    #
    # Triggers snapshot-based AoT compilation of the settled VM state to C++.
    #
    # Workflow:
    #   1. The interpreter runs the load phase normally (class defs, constants settle).
    #   2. When Frozone.compile! is reached, the block is NOT evaluated.
    #   3. Instead, the box-first emitter walks the live VM state (class table,
    #      constant table) and emits C++ — user-defined methods, settled
    #      constants, and then the block body as the execute-phase main.
    #
    # Stubs should silence the harness entry points (run_benchmark etc.) before
    # requiring the benchmark so the load phase doesn't actually run the benchmark.
    class FrozoneCompile < Node
      attr_reader :block_node

      def initialize(block_node, output_path: nil, aot_mode: false)
        @block_node = block_node
        @output_path = output_path
        @aot_mode = aot_mode
      end

      def children = [@block_node].compact

      def evaluate(context)
        # Source file of the stub (methods defined here are load-phase scaffolding,
        # not real user code — exclude them from the snapshot).
        # In --aot mode, the file IS the user code — don't exclude it.
        stub_file = @aot_mode ? nil : @block_node&.source_location&.first

        src = @block_node&.source_location&.first || $PROGRAM_NAME
        base = File.basename(src.to_s, '.rb')
        require_relative '../compiler/backend/cpp_box/emitter'
        emitter = Frozone::Compiler::Backend::CppBox::Emitter.new(base_name: base)
        if ENV['FROZONE_TI_DUMP'] == '1'
          emitter.dump_type_inference(
            execute_block: @block_node,
            top_level_scope: Vm::Core::OBJECT_CLASS,
            globals: Vm::GLOBALS,
            stub_file: stub_file
          )
          return Vm::NilObject::NIL
        end
        source = emitter.generate(
          execute_block: @block_node,
          top_level_scope: Vm::Core::OBJECT_CLASS,
          globals: Vm::GLOBALS,
          stub_file: stub_file
        )
        # Per-app gen dir: cpp/gen/box/<base>/. Each compiled program gets its
        # own subtree (own class/<Name>.hpp), so concurrent / sequential builds
        # of different programs (self-host, _unified bundle, per-stub benchmarks)
        # can't stomp a shared class/ dir.
        cpp_dir = File.expand_path("../../../cpp/gen/box/#{base}", __dir__)
        FileUtils.mkdir_p(cpp_dir)
        fixed = {
          base:             "#{base}_base.hpp",
          post:             "#{base}_post.hpp",
          layouts:          "#{base}_layouts.hpp",
          all_hpp:          "#{base}_all.hpp",
          int_literals_hpp: "#{base}_int_literals.hpp",
          int_literals_cpp: "#{base}_int_literals.cpp",
          default:          "#{base}.cpp",
          universe:         "#{base}_universe.cpp",
          static:           "#{base}_static.cpp",
          main:             "#{base}_main.cpp",
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
          # Per-owner snapshot wiring TUs: `:static_<owner>` →
          # `frozone_static_<owner>.cpp` (distributed object graph).
          return "#{base}_#{stream}.cpp" if s.start_with?("static_")
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
        # Canonical-name shims for runtime intrinsic .cpps that
        # `#include "frozone_all.hpp"` / `"frozone_base.hpp"` literally.
        # Per-stub gens use a `<base>_*` prefix on these files; the shims
        # let any per-stub gen dir serve as an `-I` root for the runtime
        # intrinsic TUs (cpp/runtime/intrinsics/*_intrinsics.cpp). Skip
        # when base IS "frozone" (the canonical name already exists).
        if base != "frozone"
          [["frozone_all.hpp", "#{base}_all.hpp"],
           ["frozone_base.hpp", "#{base}_base.hpp"]].each do |shim_name, target|
            shim_path = File.join(cpp_dir, shim_name)
            shim_content = %(#pragma once\n#include "#{target}"\n)
            prev = File.read(shim_path) rescue nil
            if prev == shim_content
              unchanged_count += 1
            else
              File.write(shim_path, shim_content)
              written_count += 1
            end
          end
        end
        $stderr.puts "Frozone.compile! (C++): #{written_count} written, #{unchanged_count} unchanged across #{outputs.size} files"

        Vm::NilObject::NIL
      end
    end
  end
end
