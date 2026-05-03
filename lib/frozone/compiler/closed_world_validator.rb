# Closed-world AOT enforcement: walk the execute-phase AST and fail
# hard on constructs that violate the closed-world contract.
#
# Two violation classes (see docs/box-first-load-execute-split.md):
#
# 1. require / require_relative / load whose candidate file is not in
#    BUILD_FILES (the closed-world source-file universe captured at
#    the load/execute boundary in split_and_load).
# 2. class / module / method / top-level constant defs reachable in
#    the execute phase. Definition effects must happen at load time;
#    any def in execute would grow the closed world at runtime.
#
# Each violation includes file:line + a brief explanation of the
# contract that was broken.
#
# Currently triggered only by box-first AOT (FROZONE_BOX_FIRST=1) —
# the legacy backend's failure modes are different and predate this
# work. Wire here when the legacy backend benefits.

require 'set'

module Frozone
  module Compiler
    module ClosedWorldValidator
      class Violation < StandardError
        attr_reader :node, :reason
        def initialize(node, reason)
          @node = node
          @reason = reason
          super(format_message)
        end

        def format_message
          loc = node.respond_to?(:source_location) ? node.source_location : nil
          loc_str = loc.is_a?(Array) ? loc.compact.join(":") : (loc || "(unknown)")
          "[closed-world] #{reason} at #{loc_str}"
        end
      end

      # Walk execute_nodes and raise Violation on the first problem.
      # build_files: Set of canonical realpaths.
      # Configurable: pass `strict_requires: false` to skip the
      # require check (e.g. while migrating).
      def self.validate!(execute_nodes, build_files:, strict_requires: true, file_stack: [])
        execute_nodes.each do |node|
          walk(node, build_files: build_files, strict_requires: strict_requires, file_stack: file_stack, in_synthetic_class_body: false, in_proc_body: false)
        end
      end

      def self.walk(node, build_files:, strict_requires:, file_stack:, in_synthetic_class_body:, in_proc_body:)
        return unless node.is_a?(Ast::Node)
        child_in_class_body = in_synthetic_class_body
        child_in_proc_body = in_proc_body || node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda)
        case node
        when Ast::ClassDef
          # Synthetic re-openings produced by --hoist-class-consts are
          # allowed: their body contains only data-init lines lifted
          # from the original class body so they can run at execute
          # phase. Recurse to validate the contents.
          if node.respond_to?(:synthetic_hoist) && node.synthetic_hoist
            child_in_class_body = true
          else
            raise Violation.new(node, "class definition in execute phase (closed-world requires class defs at load time)")
          end
        when Ast::ModuleDef
          if node.respond_to?(:synthetic_hoist) && node.synthetic_hoist
            child_in_class_body = true
          else
            raise Violation.new(node, "module definition in execute phase (closed-world requires module defs at load time)")
          end
        when Ast::MethodDef
          raise Violation.new(node, "method definition in execute phase (closed-world requires method defs at load time)")
        when Ast::SingletonClassDef
          raise Violation.new(node, "`class << expr` body in execute phase (closed-world requires it at load time)")
        when Ast::ConstantWrite
          # Constant assignment in execute phase grows the closed world,
          # except inside a synthetic class re-opening where the
          # constant slot was already declared (sentinel) at load time
          # — the execute write fills it in.
          unless in_synthetic_class_body
            raise Violation.new(node, "top-level constant write in execute phase (closed-world requires constants at load time)")
          end
        when Ast::MethodCall
          if !node.receiver_node && %i[require require_relative load].include?(node.name)
            # Requires inside Proc/Block bodies run at the time the
            # block is invoked (not at execute-phase init), and may
            # be wrapped in rescue LoadError as a best-effort load
            # idiom (e.g. optparse's Officious version proc tries
            # require_relative 'optparse/version' and rescues if
            # missing). Defer those to runtime — the binary will
            # raise LoadError at call time, matching MRI semantics.
            check_require!(node, build_files: build_files, strict_requires: strict_requires, file_stack: file_stack) unless in_proc_body
          end
        end
        # Recurse into children so violations nested inside method
        # bodies, blocks, conditionals etc. all surface.
        return unless node.respond_to?(:children)
        node.children.each do |c|
          walk(c, build_files: build_files, strict_requires: strict_requires, file_stack: file_stack, in_synthetic_class_body: child_in_class_body, in_proc_body: child_in_proc_body)
        end
      end

      # `require 'x'` validation: resolve the candidate path Ruby
      # would use, and check membership in build_files. Non-literal
      # arguments (computed paths) get their own treatment.
      def self.check_require!(node, build_files:, strict_requires:, file_stack:)
        return unless strict_requires
        arg_nodes = node.arg_nodes || []
        return if arg_nodes.empty?
        arg = arg_nodes.first
        # Computed path: `require File.basename(...)`. We can't statically
        # know the target. Fail unless explicitly annotated (TBD).
        unless arg.is_a?(Ast::StringLiteral) || arg.is_a?(Ast::InterpolatedString)
          raise Violation.new(node, "#{node.name} with non-literal argument (closed-world requires a static target)")
        end
        # InterpolatedString with all-static parts is conceptually fine
        # but we don't fold yet; treat as non-literal for now.
        unless arg.is_a?(Ast::StringLiteral)
          raise Violation.new(node, "#{node.name} with interpolated argument (closed-world requires a static target)")
        end
        target = arg.value.respond_to?(:raw) ? arg.value.raw : arg.value.to_s
        candidate = resolve_candidate(node.name, target, file_stack: file_stack)
        unless build_files.include?(candidate)
          raise Violation.new(node, "#{node.name} #{target.inspect} → #{candidate.inspect} is not in BUILD_FILES (closed-world: target not loaded at load phase)")
        end
      end

      # Mirror Ruby's resolution rules:
      # - require: search $LOAD_PATH for `<name>.rb` (or no .rb suffix)
      # - require_relative: relative to the caller's file directory
      # - load: takes the target as-is (absolute or relative to cwd)
      # Returns the canonical realpath if found, else the unresolved
      # form for the violation message.
      def self.resolve_candidate(method_name, target, file_stack:)
        case method_name
        when :require_relative
          base_dir = file_stack.last ? File.dirname(file_stack.last) : Dir.pwd
          candidate = File.expand_path(target.end_with?(".rb") ? target : "#{target}.rb", base_dir)
          File.realpath(candidate) rescue candidate
        when :require
          $LOAD_PATH.each do |dir|
            ["#{target}.rb", target].each do |suffix|
              path = File.expand_path(suffix, dir)
              if File.exist?(path)
                return (File.realpath(path) rescue path)
              end
            end
          end
          target  # unresolved
        when :load
          path = File.expand_path(target)
          File.realpath(path) rescue path
        else
          target
        end
      end
    end
  end
end
