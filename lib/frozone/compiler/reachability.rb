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
# Public API:
#
#   reach = Frozone::Compiler::Reachability.compute(
#     execute_block:        @execute_block,
#     user_methods:         user_methods,
#     top_level_scope:      @top_level_scope,
#     universe_class_names: UNIVERSE_NAMES,
#     all_classes:          collect_all_classes_unfiltered,
#   )
#
# Returns a Set of flat-name Symbols. Universe classes are emitted
# unconditionally and are NOT included in the returned set.
#
# Sound for closed-world AOT as long as no runtime reflection
# resolves a constant by string name (`Object.const_get("Foo")`)
# without `Foo` also appearing literally somewhere. That's true for
# Frozone today; if we ever support that, the affected class needs
# to be force-rooted by the user.

require_relative '../ast/constant_path'
require_relative '../ast/constant_read'
require_relative '../ast/node'
require_relative '../vm/class_object'
require_relative '../vm/module_object'
require_relative '../vm/method'

module Frozone
  module Compiler
    module Reachability
      module_function

      def compute(execute_block:, user_methods:, top_level_scope:,
                  universe_class_names:, all_classes:,
                  instantiated_classes: [])
        reach = Set.new
        seen_bodies = Set.new
        worklist = []

        # Worklist holds [body, scope_prefixes] tuples. scope_prefixes
        # is an array of part-arrays (innermost first), used for
        # Ruby-style lexical constant lookup. Empty for top-level
        # bodies; `[["Blurhash", "Ruby"], ["Blurhash"]]` for a method
        # body inside `Blurhash::Ruby`.
        schedule_body = lambda do |body, scope_prefixes = []|
          next if body.nil? || seen_bodies.include?(body.object_id)
          seen_bodies << body.object_id
          worklist << [body, scope_prefixes]
        end

        # Schedule body + each optional-param default expression.
        # `def f(x = Foo::Bar.new)` parks the default expression on
        # the method (optional_params is `[[:x, default_ast]]`), not
        # in the body. Walking only m.body would miss its constant
        # references and prune the referenced classes.
        schedule_method = lambda do |m, scope_prefixes = []|
          next unless m.is_a?(Vm::Method)
          schedule_body.call(m.body, scope_prefixes)
          (m.optional_params || []).each do |(_n, default)|
            schedule_body.call(default, scope_prefixes) if default.is_a?(Ast::Node)
          end
          (m.optional_kw_params || []).each do |(_n, default)|
            schedule_body.call(default, scope_prefixes) if default.is_a?(Ast::Node)
          end
        end

        # Walk lexical scope (innermost first) trying each prefix
        # joined with `parts`. Falls through to the bare top-level
        # lookup last. Mirrors cpp.rb's resolve_constant — without
        # this, `Ruby` inside `Blurhash::Ruby` resolves to top-level
        # `Ruby` (the VM-bootstrap MRI-compat module) instead of
        # `Blurhash::Ruby`, dragging the wrong class into the reach
        # set and pruning the actually-needed one.
        resolve_const_to_flat = lambda do |node, scope_prefixes|
          parts =
            case node
            when Ast::ConstantRead then [node.name.to_s]
            when Ast::ConstantPath then collect_path(node)
            else return nil
            end
          parts.reject!(&:empty?)
          return nil if parts.empty?
          (scope_prefixes + [[]]).each do |prefix|
            flat = (prefix + parts).join("_").to_sym
            return flat if all_classes.key?(flat)
          end
          nil
        end

        # Class's lexical scope chain (innermost first), as part-arrays.
        # `Blurhash::Ruby` → [["Blurhash", "Ruby"], ["Blurhash"]].
        # Skips the top-level (bare) lookup — that's appended in
        # resolve_const_to_flat.
        scope_for_class = lambda do |cls|
          fname = (cls.full_name || cls.name).to_s
          parts = fname.split("::")
          (1..parts.size).map { |i| parts.first(i) }.reverse
        end

        schedule_class = lambda do |flat|
          next unless flat && all_classes.key?(flat) && reach.add?(flat)
          cls = all_classes[flat]
          scope = scope_for_class.call(cls)
          # Walk own + eigenclass bodies — they can transitively
          # reference more classes via constants.
          (cls.methods_table || {}).each_value do |m|
            schedule_method.call(m, scope)
          end
          eigen = cls.eigenclass rescue nil
          if eigen
            (eigen.methods_table || {}).each_value do |m|
              schedule_method.call(m, scope)
            end
          end
          # Ancestors (parent class + included/prepended modules) are
          # transitively reachable.
          (cls.ancestors_list rescue []).each do |a|
            next unless a.is_a?(Vm::ModuleObject)
            a_flat = (a.full_name || a.name).to_s.gsub("::", "_").to_sym
            next if universe_class_names.include?(a_flat.to_s)
            schedule_class.call(a_flat)
          end
        end

        walk_for_classes = lambda do |node, scope_prefixes|
          next unless node.is_a?(Ast::Node)
          case node
          when Ast::ConstantRead, Ast::ConstantPath
            schedule_class.call(resolve_const_to_flat.call(node, scope_prefixes))
          end
          node.children.each { |c| walk_for_classes.call(c, scope_prefixes) } if node.respond_to?(:children)
        end

        # Instantiated classes (rooted via user-constant accessors,
        # which `new XClass()` directly without going through any
        # AST node we'd otherwise see).
        instantiated_classes.each do |val|
          klass = val.respond_to?(:class_object) ? val.class_object : nil
          next unless klass
          flat = (klass.full_name || klass.name).to_s.gsub("::", "_").to_sym
          schedule_class.call(flat) unless universe_class_names.include?(flat.to_s)
        end

        # Seed worklist:
        #  - execute_block (program entry)
        #  - top-level user methods (defined on Object via def in the
        #    main script)
        #  - every universe class's overlaid method bodies (core/4.0/
        #    methods on Integer/Array/Hash/etc. CAN reference user
        #    classes via constant lookups — those references should
        #    transitively root the user classes).
        schedule_body.call(execute_block, [])
        (user_methods || {}).each_value do |m|
          schedule_method.call(m, [])
        end
        top = top_level_scope.constants_table || {}
        universe_class_names.each do |universe_name|
          cls = top[universe_name.to_sym]
          next unless cls.is_a?(Vm::ModuleObject)
          scope = scope_for_class.call(cls)
          (cls.methods_table || {}).each_value do |m|
            schedule_method.call(m, scope)
          end
          eigen = cls.eigenclass rescue nil
          if eigen
            (eigen.methods_table || {}).each_value do |m|
              schedule_method.call(m, scope)
            end
          end
        end

        until worklist.empty?
          body, scope_prefixes = worklist.shift
          walk_for_classes.call(body, scope_prefixes)
        end

        reach
      end

      def collect_path(node)
        case node
        when Ast::ConstantPath then collect_path(node.parent_node) + [node.name.to_s]
        when Ast::ConstantRead then [node.name.to_s]
        else []
        end
      end
    end
  end
end
