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
require_relative '../ast/string_literal'
require_relative '../ast/symbol_literal'
require_relative '../vm/class_object'
require_relative '../vm/module_object'
require_relative '../vm/method'
require_relative 'analysis/engine'
require_relative 'analysis/passes/reachability_pass'
require_relative 'backend/cpp_box/intrinsic_lowering'

module Frozone
  module Compiler
    module Reachability
      module_function

      def compute(execute_block:, user_methods:, top_level_scope:,
                  seed_reachable_classes:, all_classes:,
                  instantiated_classes: [], class_uses: {},
                  method_level: false)
        pass = Analysis::Passes::ReachabilityPass.new(
          execute_block:          execute_block,
          user_methods:           user_methods,
          top_level_scope:        top_level_scope,
          all_classes:            all_classes,
          seed_reachable_classes: seed_reachable_classes,
          instantiated_classes:   instantiated_classes,
          class_uses:             class_uses,
          method_level:           method_level,
        )
        values = Analysis::Engine.new(pass).run
        # Filter to Symbol keys: virtual seed nodes (Array-tagged tuples)
        # also live in the value map but they're not reachable classes.
        reach = values.each_with_object(Set.new) do |(node, v), r|
          r << node if node.is_a?(Symbol) && v == :reachable
        end
        Result.new(
          reach:               reach,
          reflection_findings: pass.reflection_findings,
          walked_methods:      pass.walked_methods,
        )
      end

      # Return value of Reachability.compute. `reach` is a Set of
      # flat-name Symbols (the classes that must be emitted). `reflection_findings`
      # is an Array of ReachabilityPass::ReflectionFinding structs — each a
      # `{method_name:, tier:, source_location:}` record for a
      # reflection call site detected during the pass. Callers filter
      # by `.tier == :d` for the actionable diagnostic set.
      #
      # `include?` and `each` delegate to `reach` so existing callers
      # (`reach.include?(flat)`, `reach.each { ... }`) still work
      # transparently.
      Result = Struct.new(:reach, :reflection_findings, :walked_methods, keyword_init: true) do
        def include?(flat) = reach.include?(flat)
        def each(&block)   = reach.each(&block)
        # Override Struct's default positional to_a — callers expect
        # iterating a Result to see the reach set members, not the
        # Struct's positional members.
        def to_a           = reach.to_a
        def size           = reach.size
      end

      # Canonical Ruby method names for the reflection primitives —
      # always in the reflection-name set regardless of whether their
      # method-table entries appear during the alias-closure walk.
      CANONICAL_REFLECTION_METHOD_NAMES = Set.new(%i[
        send __send__ public_send
        instance_variable_get instance_variable_set
        const_get const_set
      ]).freeze

      # Compute the closure of method names that resolve to a reflection
      # primitive across the reachable class set. Seeded with the
      # canonical names; extended with any method whose body is
      # identity-equal (`equal?`) to one of the canonical bodies
      # snapshotted in `Vm::CANONICAL_REFLECTION_BODIES` at end of
      # load_core. This catches `alias my_send __send__` (the aliased
      # method-table entry shares the exact body ref with __send__)
      # cleanly, without also pulling in mundane wrappers that happen
      # to call a reflection intrinsic — those wrappers don't need to
      # be in the closure because ReachabilityPass walks method bodies
      # anyway and will see the canonical MethodCall inside.
      #
      # Over-approximation is safe: if a user overrides `send` on some
      # class to do something mundane, that override's body is NOT
      # equal? to the captured canonical body, so it won't get added
      # to the closure — but the base :send in CANONICAL_REFLECTION_METHOD_NAMES
      # keeps the call site classified as reflection at the type-agnostic
      # walk stage. TI can narrow later.
      #
      # Returns a frozen Set of method-name Symbols. Used by
      # ReachabilityPass to flag MethodCall sites for tier
      # classification (see docs/reflection-under-aot.md).
      def compute_reflection_method_names(all_classes)
        names = CANONICAL_REFLECTION_METHOD_NAMES.dup
        canonical_body_ids = Set.new(Vm::CANONICAL_REFLECTION_BODIES.each_value.map(&:object_id))
        return names.freeze if canonical_body_ids.empty?
        (all_classes || {}).each_value do |cls|
          # Explicit respond_to? check — real Vm::ModuleObject always
          # responds, test doubles may not stub methods_table, and
          # walking past those is safe (they contribute no primitive).
          next unless cls.respond_to?(:methods_table)
          (cls.methods_table || {}).each do |method_name, method|
            next unless method.is_a?(Vm::Method)
            next unless method.body
            names << method_name if canonical_body_ids.include?(method.body.object_id)
          end
        end
        names.freeze
      end

      # Classify a reflection call site into one of four tiers, based
      # on the shape of the receiver and the first positional argument
      # (all six reflection primitives take the name/key as arg[0]).
      # See docs/reflection-under-aot.md — "The switch-based framing"
      # for the tier definitions:
      #
      #   :a — receiver is a constant, arg is a Symbol/String literal
      #        → fully static, resolvable at compile time
      #   :b — receiver is a constant, arg is dynamic
      #        → receiver-scoped candidate set (walk receiver's constants /
      #          methods / ivars)
      #   :c — receiver is dynamic, arg is a literal
      #        → TI narrows receiver, else over-approximate across
      #          reachable classes that have a matching slot
      #   :d — receiver and arg both dynamic
      #        → force-root or refuse
      #
      # Implicit-self receiver (receiver_node.nil?) is treated as dynamic:
      # without TI, self's type is unknown at the call site.
      def classify_reflection_call(call_node)
        return :d unless call_node.is_a?(Ast::MethodCall)
        recv = call_node.receiver_node
        arg0 = (call_node.arg_nodes || [])[0]
        recv_static = recv.is_a?(Ast::ConstantRead) || recv.is_a?(Ast::ConstantPath)
        arg_static  = arg0.is_a?(Ast::SymbolLiteral) || arg0.is_a?(Ast::StringLiteral)
        case [recv_static, arg_static]
        when [true, true]  then :a
        when [true, false] then :b
        when [false, true] then :c
        else :d
        end
      end

      # Walk an AST tree, yielding each MethodCall node whose method
      # name is in `reflection_names` — i.e., call sites for tier
      # A/B/C/D classification. The receiver_node, arg_nodes, and
      # source_location are all available on the yielded node.
      def each_reflection_call_in(node, reflection_names, &block)
        return if node.nil?
        return unless node.is_a?(Ast::Node)
        if node.is_a?(Ast::MethodCall) && reflection_names.include?(node.name.to_sym)
          block.call(node)
        end
        if node.respond_to?(:children)
          node.children.each { |c| each_reflection_call_in(c, reflection_names, &block) }
        end
      end

      # Walk an AST tree, yielding each MethodCall node's method name as
      # a Symbol. Used by ReachabilityPass under method-level to push
      # [:mname, :m] reachable for every call — the name-based fanout
      # to every class defining that name (over-approximation without
      # TI). Includes reflection calls: caller can layer tier-A/B/C
      # rooting on top of the base fanout.
      def each_method_call_name_in(node, &block)
        return if node.nil?
        return unless node.is_a?(Ast::Node)
        block.call(node.name.to_sym) if node.is_a?(Ast::MethodCall)
        if node.respond_to?(:children)
          node.children.each { |c| each_method_call_name_in(c, &block) }
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
      # Symbol, filtered to those in all_classes. Used by ReachabilityPass's
      # walk_body. Universes live in all_classes and are pre-seeded reachable,
      # so re-yielding them is a benign no-op in the engine.
      def each_class_ref_in(node, scope_prefixes, all_classes, &block)
        return if node.nil?
        return unless node.is_a?(Ast::Node)
        case node
        when Ast::ConstantRead, Ast::ConstantPath
          flat = resolve_const_to_flat(node, scope_prefixes, all_classes)
          block.call(flat) if flat && all_classes.key?(flat)
        end
        if node.respond_to?(:children)
          node.children.each { |c| each_class_ref_in(c, scope_prefixes, all_classes, &block) }
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
