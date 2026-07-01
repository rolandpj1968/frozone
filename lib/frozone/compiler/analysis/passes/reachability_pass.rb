# Class-level reachability pass on the unified analysis engine.
#
# The pass has two kinds of nodes in one lattice:
#
#   1. Class flat-name Symbols (e.g. :Integer, :Frozone_Vm_ObjectObject)
#      — the answers the compute wants. Transitively rooted from the
#      seed contributions.
#
#   2. Virtual seed nodes — tagged Array tuples that represent the four
#      classical entry sources. Each is seeded :reachable and their
#      transfer functions walk their associated content (AST bodies,
#      method tables, instantiated Vm values) and push flat-name Symbol
#      contributions. They live in the value map alongside class nodes;
#      callers of Reachability.compute filter to Symbol keys.
#
#      SEED_EXECUTE_BLOCK        — the program's top-level execution AST
#      SEED_USER_METHODS         — top-level user def'd methods
#      SEED_INSTANTIATED         — user-constant values (C++ accessors
#                                  do `new XClass()` with no AST trace)
#      [:universe_overlay, :Name] — one per universe class; walks the
#                                   core/4.0 method-body Ruby that may
#                                   reference user classes
#
# Lattice: TwoValueLattice(bottom=:unreachable, top=:reachable).
#
# Transfer (pure-push):
#   virtual node → walk associated content, push :reachable to class
#                  flat-names that appear as constant refs.
#   class node   → walk methods_table + eigenclass methods_table for
#                  more refs + push ancestor flat-names.
#
# Pure-push: no use of `lookup`. Converges in one eager drain — each
# node processed once, 2-value lattice means no re-visit on grow.

require 'set'
require_relative '../pass'
require_relative '../lattice'
require_relative '../transfer_result'
require_relative '../../../ast/constant_path'
require_relative '../../../ast/constant_read'
require_relative '../../../ast/node'
require_relative '../../../vm/class_object'
require_relative '../../../vm/module_object'
require_relative '../../../vm/method'

module Frozone
  module Compiler
    module Analysis
      module Passes
        class ReachabilityPass < Pass
          LATTICE = TwoValueLattice.new(
            bottom_value: :unreachable,
            top_value:    :reachable,
          ).freeze

          SEED_EXECUTE_BLOCK = [:execute_block].freeze
          SEED_USER_METHODS  = [:user_methods].freeze
          SEED_INSTANTIATED  = [:instantiated_classes].freeze

          def self.universe_overlay_node(name) = [:universe_overlay, name.to_sym].freeze

          def initialize(execute_block:, user_methods:, top_level_scope:,
                         all_classes:, universe_class_names:, instantiated_classes:)
            @execute_block = execute_block
            @user_methods = user_methods
            @top_level_scope = top_level_scope
            @all_classes = all_classes
            @universe_class_names = universe_class_names
            @instantiated_classes = instantiated_classes
          end

          def lattice = LATTICE

          def seed
            seeds = {
              SEED_EXECUTE_BLOCK => :reachable,
              SEED_USER_METHODS  => :reachable,
              SEED_INSTANTIATED  => :reachable,
            }
            top = @top_level_scope.constants_table || {}
            @universe_class_names.each do |name|
              cls = top[name.to_sym]
              next unless cls.is_a?(Vm::ModuleObject)
              seeds[self.class.universe_overlay_node(name)] = :reachable
            end
            seeds
          end

          def transfer(node, value, _lookup)
            return TransferResult::EMPTY unless value == :reachable
            case node
            when Array  then transfer_virtual(node)
            when Symbol then transfer_class(node)
            else TransferResult::EMPTY
            end
          end

          private

          def transfer_virtual(node)
            pushes = {}
            case node[0]
            when :execute_block
              walk_body(@execute_block, [], pushes)
            when :user_methods
              (@user_methods || {}).each_value { |m| walk_method(m, [], pushes) }
            when :instantiated_classes
              @instantiated_classes.each { |val| push_instantiated(val, pushes) }
            when :universe_overlay
              cls = (@top_level_scope.constants_table || {})[node[1]]
              return TransferResult::EMPTY unless cls.is_a?(Vm::ModuleObject)
              scope = Reachability.scope_for_class(cls)
              walk_methods(cls.methods_table, scope, pushes)
              eigen = cls.eigenclass rescue nil
              walk_methods(eigen.methods_table, scope, pushes) if eigen
            end
            pushes.empty? ? TransferResult::EMPTY : TransferResult.push(pushes)
          end

          def transfer_class(flat_name)
            cls = @all_classes[flat_name]
            return TransferResult::EMPTY unless cls
            pushes = {}
            push_method_refs(cls, pushes)
            push_ancestors(cls, pushes)
            pushes.empty? ? TransferResult::EMPTY : TransferResult.push(pushes)
          end

          def push_instantiated(val, pushes)
            klass = val.respond_to?(:class_object) ? val.class_object : nil
            return unless klass
            flat = Reachability.flat_name(klass)
            return if @universe_class_names.include?(flat.to_s)
            pushes[flat] = :reachable if @all_classes.key?(flat)
          end

          def push_method_refs(cls, pushes)
            scope = Reachability.scope_for_class(cls)
            walk_methods(cls.methods_table, scope, pushes)
            eigen = cls.eigenclass rescue nil
            walk_methods(eigen.methods_table, scope, pushes) if eigen
          end

          def walk_methods(methods_table, scope, pushes)
            return unless methods_table
            methods_table.each_value { |m| walk_method(m, scope, pushes) }
          end

          # Walk a single method: body + default expressions for optional
          # positional/keyword params (defaults park on the Method, not
          # in the body — miss them and we'd prune classes named there).
          def walk_method(m, scope, pushes)
            return unless m.is_a?(Vm::Method)
            walk_body(m.body, scope, pushes)
            (m.optional_params || []).each do |(_, d)|
              walk_body(d, scope, pushes) if d.is_a?(Ast::Node)
            end
            (m.optional_kw_params || []).each do |(_, d)|
              walk_body(d, scope, pushes) if d.is_a?(Ast::Node)
            end
          end

          def walk_body(body, scope, pushes)
            return if body.nil?
            Reachability.each_class_ref_in(body, scope, @all_classes, @universe_class_names) do |flat|
              pushes[flat] = :reachable
            end
          end

          def push_ancestors(cls, pushes)
            (cls.ancestors_list rescue []).each do |a|
              next unless a.is_a?(Vm::ModuleObject)
              flat = Reachability.flat_name(a)
              next if @universe_class_names.include?(flat.to_s)
              # Old `schedule_class` filtered via all_classes.key?(flat);
              # apply the same check here so spurious ancestors (not in
              # the closed-world snapshot) don't pollute the reach set.
              next unless @all_classes.key?(flat)
              pushes[flat] = :reachable
            end
          end
        end
      end
    end
  end
end
