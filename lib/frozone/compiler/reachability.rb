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
# As of the TI v2 framework, the analysis runs on the unified
# `Analysis::Engine`. `Reachability.compute` is a thin wrapper: it
# constructs a `ReachabilityPass` with the entry-source inputs
# (execute_block, user_methods, universe overlays, instantiated
# constants) and runs the engine. The pass models the four entry
# sources as virtual seed nodes with dedicated transfer functions;
# no seed-discovery walk happens outside the engine.
#
# This module retains four helpers used directly by the emitter
# and by ReachabilityPass:
#
#   .compute(...)            — main entry point; returns Set[Symbol]
#   .resolve_const_to_flat   — Ast::ConstantRead/Path → flat name
#   .collect_path            — Ast::ConstantPath → component parts
#   .scope_for_class         — class → lexical scope chain
#   .each_class_ref_in       — walk AST, yield each referenced class
#
# Sound for closed-world AOT as long as no runtime reflection
# resolves a constant by string name (`Object.const_get("Foo")`)
# without `Foo` also appearing literally somewhere. That's true for
# Frozone today; if we ever support that, the affected class needs
# to be force-rooted by the user.

require 'set'
require_relative '../ast/constant_path'
require_relative '../ast/constant_read'
require_relative '../ast/method_call'
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
                  instantiated_classes: [], class_uses: {})
        pass = Analysis::Passes::ReachabilityPass.new(
          execute_block:        execute_block,
          user_methods:         user_methods,
          top_level_scope:      top_level_scope,
          all_classes:          all_classes,
          universe_class_names: universe_class_names,
          instantiated_classes: instantiated_classes,
          class_uses:           class_uses,
        )
        values = Analysis::Engine.new(pass).run
        # Filter to Symbol keys: virtual seed nodes (Array-tagged tuples)
        # also live in the value map but they're not reachable classes.
        values.each_with_object(Set.new) do |(node, v), reach|
          reach << node if node.is_a?(Symbol) && v == :reachable
        end
      end

      # Walk an AST tree, yielding each `Intrinsics.X(...)` call's method
      # name (a Symbol like :regexp_new). Used by ReachabilityPass to
      # look up the intrinsic's declared class dependencies via
      # IntrinsicLowering.uses_of and push them as reachable.
      def each_intrinsic_ref_in(node, &block)
        return if node.nil?
        return unless node.is_a?(Ast::Node)
        if node.is_a?(Ast::MethodCall)
          recv = node.receiver_node
          if recv.is_a?(Ast::ConstantRead) && recv.name.to_sym == :Intrinsics
            block.call(node.name.to_sym)
          end
        end
        if node.respond_to?(:children)
          node.children.each { |c| each_intrinsic_ref_in(c, &block) }
        end
      end

      # Walk an AST tree, yielding each referenced class as a flat-name
      # Symbol, filtered to those in all_classes and not in
      # universe_class_names. Used by ReachabilityPass's walk_body.
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

      # Canonicalise a Ruby full-name into its flat form. Escapes source
      # `_` to `__` FIRST so that `Foo_Bar` (bare, with underscore) and
      # `Foo::Bar` (nested) don't collide:
      #
      #   `Foo_Bar`      → `Foo__Bar`
      #   `Foo::Bar`     → `Foo_Bar`
      #   `Foo::Bar_Baz` → `Foo_Bar__Baz`
      #
      # Single canonicalisation point serving reachability, the
      # C++ class-name emitter, and every other flat-name site.
      def flatten(fname_str) = fname_str.to_s.gsub("_", "__").gsub("::", "_")

      # Flat-name of a Vm::Class/Module as Symbol. Preferred convenience
      # for hash-key + comparison sites.
      def flat_name(cls) = flatten(cls.full_name || cls.name).to_sym

      # Compose a flat Symbol from an already-flat prefix and a bare
      # short-name Symbol (typically a constants_table key). Applies the
      # `_` → `__` escape to the short name so composition matches the
      # single-pass `flatten` result:
      #
      #   compose_flat(nil,  :Foo)      → :Foo
      #   compose_flat(:Foo, :Bar)      → :Foo_Bar
      #   compose_flat(nil,  :Foo_X)    → :Foo__X
      #   compose_flat(:Foo, :Bar_Y)    → :Foo_Bar__Y
      #
      # For the walk-with-prefix pattern in the emitter's
      # collect_all_classes / collect_user_constants — passing raw
      # `:"#{prefix}_#{name}"` would bypass the escape and produce
      # class-key mismatches vs `flat_name(cls)`.
      def compose_flat(prefix, short_name)
        escaped = short_name.to_s.gsub("_", "__")
        prefix ? :"#{prefix}_#{escaped}" : escaped.to_sym
      end

      # Eigenclass name convention. Short `_eig` suffix — collision-safe
      # against user class `Foo_eig` (source `_` escapes to `__`, so it
      # becomes `Foo__eig`, distinct from eigenclass-of-Foo's `Foo_eig`).
      # A nod to the Eigerwand while we're mangling names. Lowercase
      # matters: Ruby class names start uppercase, so no valid Ruby
      # class can collapse to a `_eig`-suffixed form.
      EIG_SUFFIX = "_eig"
      def eigenclass_name(cls) = "#{flatten(cls.full_name)}#{EIG_SUFFIX}"
      def eigenclass_flat(cls) = eigenclass_name(cls).to_sym

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
    end
  end
end
