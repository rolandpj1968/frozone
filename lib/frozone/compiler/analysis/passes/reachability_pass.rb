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
require_relative '../../../ast/method_call'
require_relative '../../../ast/node'
require_relative '../../../vm/class_object'
require_relative '../../../vm/module_object'
require_relative '../../../vm/method'
require_relative '../../../vm/array_object'
require_relative '../../../vm/hash_object'
require_relative '../../backend/cpp_box/intrinsic_lowering'

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
                         all_classes:, universe_class_names:, instantiated_classes:,
                         class_uses: {})
            @execute_block = execute_block
            @user_methods = user_methods
            @top_level_scope = top_level_scope
            @all_classes = all_classes
            @universe_class_names = universe_class_names
            @instantiated_classes = instantiated_classes
            @class_uses = class_uses
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
              # Push hand-coded C++ class-body dependencies declared on
              # the universe class's RubyClass entry (task #219). Sibling
              # mechanism to IntrinsicLowering::INTRINSIC_USES for
              # class-level (not intrinsic-level) declarations.
              push_class_uses(node[1], pushes)
            end
            pushes.empty? ? TransferResult::EMPTY : TransferResult.push(pushes)
          end

          def transfer_class(flat_name)
            cls = @all_classes[flat_name]
            return TransferResult::EMPTY unless cls
            pushes = {}
            push_method_refs(cls, pushes)
            push_ancestors(cls, pushes)
            push_constant_values(cls, pushes)
            pushes.empty? ? TransferResult::EMPTY : TransferResult.push(pushes)
          end

          def push_instantiated(val, pushes)
            walk_value(val, pushes, Set.new)
          end

          # Walk the class's own constants_table for runtime-state class
          # refs that leave no AST trace. `CLASSES = [Foo, Bar]` inside a
          # class body is evaluated at load-time — the array literal AST
          # is discarded, but the resulting ArrayObject sits in
          # constants_table containing live Class pointers. AST-only
          # walking would miss them.
          def push_constant_values(cls, pushes)
            seen = Set.new
            (cls.constants_table || {}).each_value do |val|
              walk_value(val, pushes, seen)
            end
          end

          # Traverse a runtime Vm value looking for embedded class refs.
          # Direct Class/Module refs push their flat name; container
          # values (Array, Hash) recurse into contents; other Vm objects
          # have their class_object rooted. Cycle-guarded via `seen`.
          def walk_value(val, pushes, seen)
            return if val.nil?
            oid = val.object_id
            return if seen.include?(oid)
            seen.add(oid)

            # Explicit is_a? checks (not case/when — Class#=== bypasses
            # is_a?, breaking rspec stubbing on doubles).
            if val.is_a?(Vm::ModuleObject)
              # Vm::ClassObject < Vm::ModuleObject, so this handles both.
              push_class_flat_name(val, pushes)
            elsif val.is_a?(Vm::ArrayObject)
              push_instance_class(val, pushes)
              (val.raw rescue []).each { |elem| walk_value(elem, pushes, seen) }
            elsif val.is_a?(Vm::HashObject)
              push_instance_class(val, pushes)
              (val.raw rescue {}).each do |k, v|
                walk_value(k, pushes, seen)
                walk_value(v, pushes, seen)
              end
            else
              push_instance_class(val, pushes)
            end
          end

          # Push a Vm class's flat name if it's in-universe (i.e., not a
          # hand-coded universe class that we always emit) and in the
          # closed-world snapshot.
          def push_class_flat_name(cls, pushes)
            flat = Reachability.flat_name(cls)
            return if @universe_class_names.include?(flat.to_s)
            pushes[flat] = :reachable if @all_classes.key?(flat)
          end

          # For a non-Class Vm value: root its class_object. Same shape
          # as the old push_instantiated logic — an instantiated user
          # constant transitively requires its class to be reachable.
          def push_instance_class(val, pushes)
            return unless val.respond_to?(:class_object)
            klass = val.class_object
            return unless klass
            push_class_flat_name(klass, pushes)
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
            # Intrinsic-declared dependencies: `Intrinsics.X(...)` calls
            # in the body pull in each class listed in the intrinsic's
            # `uses:` declaration. Closes the RegexpError-genus gap
            # where a C++ intrinsic body constructs or raises a class
            # not visible in any Ruby AST leading to it.
            Reachability.each_intrinsic_ref_in(body) do |intrinsic_name|
              Backend::CppBox::IntrinsicLowering.uses_of(intrinsic_name).each do |cls_sym|
                flat = Reachability.flatten(cls_sym.to_s).to_sym
                next if @universe_class_names.include?(flat.to_s)
                pushes[flat] = :reachable if @all_classes.key?(flat)
              end
            end
          end

          def push_class_uses(universe_name_sym, pushes)
            list = @class_uses[universe_name_sym]
            return unless list && !list.empty?
            list.each do |cls_sym|
              flat = Reachability.flatten(cls_sym.to_s).to_sym
              next if @universe_class_names.include?(flat.to_s)
              pushes[flat] = :reachable if @all_classes.key?(flat)
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
