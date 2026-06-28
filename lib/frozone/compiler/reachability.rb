# Backend-independent class reachability analysis for closed-world
# AOT compilation. Without pruning, every Vm::ClassObject in the
# top-level scope (i.e. all of `lib/core/4.0/`) gets emitted into
# every generated program — Time, Set, Complex, every Errno
# subclass, etc. For a 3-line user script that's ~480k LoC of cpp
# output and a 64MB binary. Pruning to only what's actually reached
# from the program's entry point cuts this by ~90% on small programs.
#
# Conservative class-level analysis (no per-method tracking yet):
# a class is "reachable" iff
#   1. its constant name appears in some reachable AST as a
#      ConstantRead / ConstantPath, OR
#   2. it's an ancestor (parent class or included module) of a
#      reachable class.
# Method bodies of reachable classes are walked transitively.
#
# As of the TI v2 framework, the worklist + monotone-grow dataflow
# runs on the unified `Analysis::Engine`. The migration preserved
# the public surface (Reachability.compute returns a Set of flat-name
# Symbols) while expressing the analysis as a `ReachabilityPass`
# (lib/frozone/compiler/analysis/passes/reachability_pass.rb).
#
# This module retains three helpers used directly by the emitter:
#
#   .compute(...)            — main entry point; returns Set[Symbol]
#   .resolve_const_to_flat   — Ast::ConstantRead/Path → flat name
#   .collect_path            — Ast::ConstantPath → component parts
#   .scope_for_class         — class → lexical scope chain
#   .each_class_ref_in       — walk AST, yield each referenced class
#                               (used internally by the seed-discovery
#                               and the ReachabilityPass transfer)
#
# Sound for closed-world AOT as long as no runtime reflection
# resolves a constant by string name (`Object.const_get("Foo")`)
# without `Foo` also appearing literally somewhere. That's true for
# Frozone today; if we ever support that, the affected class needs
# to be force-rooted by the user.

require 'set'
require_relative '../ast/constant_path'
require_relative '../ast/constant_read'
require_relative '../ast/node'
require_relative '../vm/class_object'
require_relative '../vm/module_object'
require_relative '../vm/method'
require_relative 'analysis/engine'
require_relative 'analysis/passes/reachability_pass'

module Frozone
  module Compiler
    module Reachability
      module_function

      def compute(execute_block:, user_methods:, top_level_scope:,
                  universe_class_names:, all_classes:,
                  instantiated_classes: [])
        seed_classes = discover_seed_classes(
          execute_block:        execute_block,
          user_methods:         user_methods,
          top_level_scope:      top_level_scope,
          universe_class_names: universe_class_names,
          all_classes:          all_classes,
          instantiated_classes: instantiated_classes,
        )
        pass = Analysis::Passes::ReachabilityPass.new(
          all_classes:          all_classes,
          universe_class_names: universe_class_names,
          seed_classes:         seed_classes,
        )
        values = Analysis::Engine.new(pass).run
        values.each_with_object(Set.new) do |(flat, v), reach|
          reach << flat if v == :reachable
        end
      end

      # Walk an AST tree, yielding each referenced class as a
      # flat-name Symbol, filtered to those in all_classes and not
      # in universe_class_names. Shared between the seed-discovery
      # phase here and the ReachabilityPass#transfer.
      def each_class_ref_in(node, scope_prefixes, all_classes, universe_class_names, &block)
        return if node.nil?
        return unless node.is_a?(Ast::Node)
        case node
        when Ast::ConstantRead, Ast::ConstantPath
          flat = resolve_const_to_flat(node, scope_prefixes, all_classes)
          if flat && all_classes.key?(flat) && !universe_class_names.include?(flat.to_s)
            block.call(flat)
          end
        end
        if node.respond_to?(:children)
          node.children.each { |c| each_class_ref_in(c, scope_prefixes, all_classes, universe_class_names, &block) }
        end
      end

      def collect_path(node)
        case node
        when Ast::ConstantPath then collect_path(node.parent_node) + [node.name.to_s]
        when Ast::ConstantRead then [node.name.to_s]
        else []
        end
      end

      # Class's lexical scope chain (innermost first), as part-arrays.
      # `Blurhash::Ruby` → [["Blurhash", "Ruby"], ["Blurhash"]].
      # The bare top-level lookup (empty prefix) is added by callers.
      def scope_for_class(cls)
        fname = (cls.full_name || cls.name).to_s
        parts = fname.split("::")
        (1..parts.size).map { |i| parts.first(i) }.reverse
      end

      # Resolve a ConstantRead/ConstantPath node to a flat
      # @user_classes key, walking lexical scope (innermost first)
      # before the bare top-level lookup. Mirrors cpp.rb's
      # resolve_constant. Returns nil if no matching class found.
      def resolve_const_to_flat(node, scope_prefixes, all_classes)
        parts = collect_path(node)
        parts.reject!(&:empty?)
        return nil if parts.empty?
        (scope_prefixes + [[]]).each do |prefix|
          flat = (prefix + parts).join("_").to_sym
          return flat if all_classes.key?(flat)
        end
        nil
      end

      # Compute the initial set of reachable classes by walking the four
      # entry sources (instantiated constants, execute_block,
      # user_methods, universe overlays). The resulting Set feeds the
      # engine's seed; from there the engine transitively discovers the
      # rest via ReachabilityPass#transfer.
      def discover_seed_classes(execute_block:, user_methods:, top_level_scope:,
                                 universe_class_names:, all_classes:,
                                 instantiated_classes:)
        seed = Set.new

        # 1. Instantiated classes (rooted via user-constant accessors
        #    that directly `new XClass()` in C++ — no AST trace).
        instantiated_classes.each do |val|
          klass = val.respond_to?(:class_object) ? val.class_object : nil
          next unless klass
          flat = (klass.full_name || klass.name).to_s.gsub("::", "_").to_sym
          next if universe_class_names.include?(flat.to_s)
          seed << flat if all_classes.key?(flat)
        end

        # 2. The program's execute block.
        each_class_ref_in(execute_block, [], all_classes, universe_class_names) do |f|
          seed << f
        end

        # 3. User-defined top-level methods.
        (user_methods || {}).each_value do |m|
          walk_method_for_seed(m, [], all_classes, universe_class_names, seed)
        end

        # 4. Universe class overlays (core/4.0/ method bodies CAN
        #    reference user classes via constant lookups — those
        #    references should transitively root the user classes).
        top = top_level_scope.constants_table || {}
        universe_class_names.each do |universe_name|
          cls = top[universe_name.to_sym]
          next unless cls.is_a?(Vm::ModuleObject)
          scope = scope_for_class(cls)
          (cls.methods_table || {}).each_value do |m|
            walk_method_for_seed(m, scope, all_classes, universe_class_names, seed)
          end
          eigen = cls.eigenclass rescue nil
          next unless eigen
          (eigen.methods_table || {}).each_value do |m|
            walk_method_for_seed(m, scope, all_classes, universe_class_names, seed)
          end
        end

        seed
      end

      def walk_method_for_seed(m, scope, all_classes, universe_class_names, seed)
        return unless m.is_a?(Vm::Method)
        each_class_ref_in(m.body, scope, all_classes, universe_class_names) { |f| seed << f }
        (m.optional_params || []).each do |(_, d)|
          each_class_ref_in(d, scope, all_classes, universe_class_names) { |f| seed << f } if d.is_a?(Ast::Node)
        end
        (m.optional_kw_params || []).each do |(_, d)|
          each_class_ref_in(d, scope, all_classes, universe_class_names) { |f| seed << f } if d.is_a?(Ast::Node)
        end
      end
    end
  end
end
