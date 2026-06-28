# Class-level reachability pass — the first migration onto the
# unified analysis engine. Replaces what was a custom closure-based
# worklist algorithm in lib/frozone/compiler/reachability.rb.
#
# Nodes:    class flat-name Symbols (e.g. :Integer, :Frozone_Vm_ObjectObject)
# Lattice:  TwoValueLattice(bottom=:unreachable, top=:reachable)
# Seed:     pre-discovered initially-reachable classes (the caller
#           walks execute_block, user_methods, universe overlays, and
#           instantiated constants to compute this set — Reachability
#           module exposes that logic)
# Transfer (push): when a class becomes :reachable, walk its method
#           bodies + eigenclass methods + ancestor chain and push
#           :reachable to every referenced class that is in
#           `all_classes` and not in `universe_class_names`.
#
# Pure-push: no use of `lookup`. The transfer's outputs are entirely
# the contribution Hash. The pass converges in a single eager drain
# for typical programs (each reachable class processed exactly once;
# the 2-level lattice means no re-visit on monotone-grow).

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

          def initialize(all_classes:, universe_class_names:, seed_classes:)
            @all_classes = all_classes
            @universe_class_names = universe_class_names
            @seed_classes = seed_classes
          end

          def lattice = LATTICE

          def seed
            @seed_classes.each_with_object({}) { |flat, h| h[flat] = :reachable }
          end

          def transfer(flat_name, value, _lookup)
            return TransferResult::EMPTY unless value == :reachable
            cls = @all_classes[flat_name]
            return TransferResult::EMPTY unless cls
            pushes = {}
            push_method_refs(cls, pushes)
            push_ancestors(cls, pushes)
            pushes.empty? ? TransferResult::EMPTY : TransferResult.push(pushes)
          end

          private

          def push_method_refs(cls, pushes)
            scope = Reachability.scope_for_class(cls)
            walk_methods(cls.methods_table, scope, pushes)
            eigen = cls.eigenclass rescue nil
            walk_methods(eigen.methods_table, scope, pushes) if eigen
          end

          def walk_methods(methods_table, scope, pushes)
            return unless methods_table
            methods_table.each_value do |m|
              next unless m.is_a?(Vm::Method)
              walk_body(m.body, scope, pushes)
              # def f(x = Foo::Bar.new) — defaults park on the method,
              # not in the body; need to walk them too or we'd prune Foo.
              (m.optional_params || []).each do |(_, d)|
                walk_body(d, scope, pushes) if d.is_a?(Ast::Node)
              end
              (m.optional_kw_params || []).each do |(_, d)|
                walk_body(d, scope, pushes) if d.is_a?(Ast::Node)
              end
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
              flat = (a.full_name || a.name).to_s.gsub("::", "_").to_sym
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
