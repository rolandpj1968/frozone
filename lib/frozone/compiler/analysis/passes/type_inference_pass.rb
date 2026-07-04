# Tier-1 type inference: concrete-class-only, flow-insensitive
# ("0-CFA over the class hierarchy"). Runs on the unified analysis
# engine.
#
# ------------------------------------------------------------------
# Node kinds
# ------------------------------------------------------------------
#
#   [:method, class_flat, method_name]
#     — value is the method's return type. This is the ONLY node
#       kind visible to the engine; every other TI product hangs off
#       the pass's side tables.
#
# The per-AST-node type map (the "answer cache" from the framework
# plan) is populated as a side effect of the transfer walk and
# exposed via `#type_of(node)`. It is NOT part of the engine's
# value map because it isn't a lattice fixpoint — it's a deterministic
# function of the current method-return-type snapshot, recomputed
# from scratch each time the transfer runs for that method.
#
# ------------------------------------------------------------------
# Transfer shape (Tier 1)
# ------------------------------------------------------------------
#
# For each `[:method, C, m]` node, walk C.methods_table[m]'s body:
#
#   - Type-env: `local var name → Type` for the enclosing method.
#     Flow-insensitive — all writes to a var are joined into its
#     single per-method type. Parameters default to ⊤.
#
#   - Structural transfer over AST nodes:
#       literals            → their class type
#       self                → the enclosing class's instance type
#       LocalVariableRead   → env[name] (⊤ if unknown)
#       LocalVariableWrite  → env[name] = type_of(value); expr type = value
#       If                  → join(then_type, else_type or nil_type)
#       Return              → contributes to the method's return type,
#                             expression type is ⊥ (divergent)
#       MethodCall          → target class × method name → lookup return
#                             type via engine (or ⊤ if target unknown)
#       (everything else)   → ⊤ for now; extend incrementally
#
#   - The method's return type is the join of all Return contributions
#     plus the terminal expression type. Divergent (⊥) paths don't
#     contribute.
#
# Anything unhandled degrades to ⊤ — the safe default under our lattice.

require 'set'
require_relative '../pass'
require_relative '../lattice'
require_relative '../type_lattice'
require_relative '../transfer_result'
require_relative '../../../ast/node'

module Frozone
  module Compiler
    module Analysis
      module Passes
        class TypeInferencePass < Pass
          # Node-kind tag for methods in the engine's value map.
          def self.method_node(class_flat, method_name)
            [:method, class_flat.to_sym, method_name.to_sym].freeze
          end

          # `methods` — Hash [class_flat, method_name] → Vm::Method
          # `all_classes` — Hash flat_name → Vm::ModuleObject (for the lattice)
          def initialize(methods:, all_classes:)
            @methods = methods
            @lattice = TypeLattice.new(all_classes)
            @per_node_types = {}
          end

          def lattice = @lattice

          # Type accessor for callers (emitter, tests). Nil for AST nodes
          # the pass never visited (unreachable methods, or nodes outside
          # any method body).
          def type_of(node) = @per_node_types[node]

          def seed
            seeds = {}
            @methods.each_key do |(cls_flat, mname)|
              seeds[self.class.method_node(cls_flat, mname)] = @lattice.bottom
            end
            seeds
          end

          def transfer(node, _current, lookup)
            return TransferResult::EMPTY unless node.is_a?(Array) && node[0] == :method
            _, cls_flat, mname = node
            method = @methods[[cls_flat, mname]]
            return TransferResult::EMPTY unless method

            ctx = TransferCtx.new(
              class_flat: cls_flat,
              method_name: mname,
              env:         {},
              return_joins: [],
              lookup:      lookup,
            )
            seed_params(method, ctx)
            terminal_type = walk(method.body, ctx)
            # Terminal expression + all explicit Return contributions
            return_type = ctx.return_joins.reduce(terminal_type) { |acc, t| @lattice.join(acc, t) }
            return_type = @lattice.top if return_type.equal?(@lattice.bottom)
            TransferResult.pull(return_type)
          end

          private

          TransferCtx = Struct.new(:class_flat, :method_name, :env, :return_joins, :lookup, keyword_init: true)

          # Parameters default to ⊤ under Tier 1 (no callsite-type
          # propagation yet). Later: bidirectional inference will feed
          # narrower params in from callsites.
          def seed_params(method, ctx)
            (method.required_params || []).each { |name| ctx.env[name] = @lattice.top }
            (method.optional_params || []).each { |(name, _default)| ctx.env[name] = @lattice.top }
            ctx.env[method.rest_param] = @lattice.concrete(:Array) if method.respond_to?(:rest_param) && method.rest_param
          end

          # Type of any AST expression. Result is memoised in the per-node
          # map both for the emitter's benefit and for cheap re-visits.
          def walk(node, ctx)
            return @lattice.top if node.nil?
            t = compute(node, ctx)
            @per_node_types[node] = t
            t
          end

          def compute(node, ctx)
            case node
            when Ast::IntegerLiteral    then @lattice.concrete(:Integer)
            when Ast::FloatLiteral      then @lattice.concrete(:Float)
            when Ast::StringLiteral     then @lattice.concrete(:String)
            when Ast::SymbolLiteral     then @lattice.concrete(:Symbol)
            when Ast::TrueLiteral       then @lattice.concrete(:TrueClass)
            when Ast::FalseLiteral      then @lattice.concrete(:FalseClass)
            when Ast::NilLiteral        then @lattice.concrete(:NilClass)
            when Ast::ArrayLiteral      then @lattice.concrete(:Array)
            when Ast::HashLiteral       then @lattice.concrete(:Hash)
            when Ast::SelfLiteral       then @lattice.concrete(ctx.class_flat)
            when Ast::LocalVariableRead then ctx.env[node.name] || @lattice.top
            when Ast::LocalVariableWrite then transfer_local_write(node, ctx)
            when Ast::If                 then transfer_if(node, ctx)
            when Ast::Return             then transfer_return(node, ctx)
            when Ast::MethodCall         then transfer_method_call(node, ctx)
            else
              # Recurse into children (their types get cached), but the
              # node itself is ⊤ until we add a handler for its kind.
              # Prevents whole subtrees going untyped just because their
              # root is unhandled.
              walk_children(node, ctx)
              @lattice.top
            end
          end

          def walk_children(node, ctx)
            return unless node.respond_to?(:children)
            node.children.each { |c| walk(c, ctx) if c.is_a?(Ast::Node) }
          end

          def transfer_local_write(node, ctx)
            rhs_type = walk(node.value_node, ctx)
            # Flow-insensitive join: every write to this var contributes.
            prev = ctx.env[node.name]
            ctx.env[node.name] = prev ? @lattice.join(prev, rhs_type) : rhs_type
            rhs_type
          end

          def transfer_if(node, ctx)
            # Predicate type isn't used at Tier 1 (no branch narrowing) —
            # but walk it so its subtree gets cached.
            walk(node.pred_node, ctx)
            then_type = walk(node.then_node, ctx)
            else_type = node.else_node ? walk(node.else_node, ctx) : @lattice.nil_type
            @lattice.join(then_type, else_type)
          end

          def transfer_return(node, ctx)
            value_type = node.value_node ? walk(node.value_node, ctx) : @lattice.nil_type
            ctx.return_joins << value_type
            # `return` diverges — the enclosing expression doesn't receive
            # this value.
            @lattice.bottom
          end

          # Method-call return-type resolution. Tier 1:
          #   - receiver type = ⊤ or unknown → return type = ⊤
          #   - receiver type = concrete C, method registered on C → look up
          #     C.m's return-type node in the engine's value map
          #   - method is on a class we don't have in @methods (universe /
          #     hand-coded) → ⊤ for now; intrinsic-return-type map is a
          #     follow-up.
          def transfer_method_call(node, ctx)
            # Walk receiver + args + block so their types get cached.
            recv_type = node.receiver_node ? walk(node.receiver_node, ctx) : @lattice.concrete(ctx.class_flat)
            (node.arg_nodes || []).each { |a| walk(a, ctx) }
            walk(node.block_node, ctx) if node.block_node

            return @lattice.top if recv_type.top? || recv_type.bottom?
            recv_class = recv_type.concrete
            # <boolean> receiver: no obvious way to look up "the" method's
            # return without splitting into TrueClass/FalseClass; punt.
            return @lattice.top if recv_class == :__boolean__ || !@methods.key?([recv_class, node.name])

            ctx.lookup.call(self.class.method_node(recv_class, node.name))
          end
        end
      end
    end
  end
end
