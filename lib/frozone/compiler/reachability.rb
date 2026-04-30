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

        schedule_body = lambda do |body|
          next if body.nil? || seen_bodies.include?(body.object_id)
          seen_bodies << body.object_id
          worklist << body
        end

        resolve_const_to_flat = lambda do |node|
          parts =
            case node
            when Ast::ConstantRead then [node.name.to_s]
            when Ast::ConstantPath then collect_path(node)
            else return nil
            end
          parts.reject!(&:empty?)
          return nil if parts.empty?
          flat = parts.join("_").to_sym
          all_classes.key?(flat) ? flat : nil
        end

        schedule_class = lambda do |flat|
          next unless flat && all_classes.key?(flat) && reach.add?(flat)
          cls = all_classes[flat]
          # Walk own + eigenclass bodies — they can transitively
          # reference more classes via constants.
          (cls.methods_table || {}).each_value do |m|
            schedule_body.call(m.body) if m.is_a?(Vm::Method)
          end
          eigen = cls.eigenclass rescue nil
          if eigen
            (eigen.methods_table || {}).each_value do |m|
              schedule_body.call(m.body) if m.is_a?(Vm::Method)
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

        walk_for_classes = lambda do |node|
          next unless node.is_a?(Ast::Node)
          case node
          when Ast::ConstantRead, Ast::ConstantPath
            schedule_class.call(resolve_const_to_flat.call(node))
          end
          node.children.each { |c| walk_for_classes.call(c) } if node.respond_to?(:children)
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
        schedule_body.call(execute_block)
        (user_methods || {}).each_value do |m|
          schedule_body.call(m.body) if m.is_a?(Vm::Method)
        end
        top = top_level_scope.constants_table || {}
        universe_class_names.each do |universe_name|
          cls = top[universe_name.to_sym]
          next unless cls.is_a?(Vm::ModuleObject)
          (cls.methods_table || {}).each_value do |m|
            schedule_body.call(m.body) if m.is_a?(Vm::Method)
          end
          eigen = cls.eigenclass rescue nil
          if eigen
            (eigen.methods_table || {}).each_value do |m|
              schedule_body.call(m.body) if m.is_a?(Vm::Method)
            end
          end
        end

        until worklist.empty?
          walk_for_classes.call(worklist.shift)
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
