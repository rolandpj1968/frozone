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
require_relative '../../reachability'
require_relative '../../backend/cpp_box/intrinsic_lowering'

module Frozone
  module Compiler
    module Analysis
      module Passes
        class TypeInferencePass < Pass
          # Node-kind tag for methods in the engine's value map.
          def self.method_node(class_flat, method_name)
            [:method, class_flat.to_sym, method_name.to_sym].freeze
          end

          # `methods` — Hash [class_flat, method_name] → Vm::Method for
          # EVERY reachable class with a walkable Ruby body — user classes
          # AND universe classes alike. Universe classes are not special
          # to TI: they're just classes with some methods whose bodies
          # terminate in Intrinsics.foo calls. The Ruby↔C++ membrane is
          # exclusively Intrinsics (annotated via INTRINSIC_RETURN_TYPES),
          # so a class being "hand-coded structure" says nothing about
          # whether TI can walk its method bodies. Hand-coded RubyClass
          # overrides (raw C++ strings) are the actual TI-blind spot —
          # those aren't Vm::Method entries and shouldn't appear in
          # `methods` here; each occurrence is a de-intrinsification
          # candidate.
          # `all_classes` — Hash flat_name → Vm::ModuleObject (for the lattice)
          # `top_level_scope` — Object's constants_table for ConstantRead
          #                    resolution. Optional; defaults to no scope
          #                    (all ConstantRead types as ⊤).
          def initialize(methods:, all_classes:, top_level_scope: nil)
            @methods = methods
            @top_level_scope = top_level_scope
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
              break_joins: [],
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

          # `break_joins` — stack of Arrays, one per enclosing break-catching
          # scope (Wave-1 loops; later, blocks). `Break` pushes its value
          # type onto the top array; the loop transfer pops and joins the
          # collected values into its own result (a plain while returns
          # nil, but `while true; break 42; end` returns Integer).
          TransferCtx = Struct.new(:class_flat, :method_name, :env, :return_joins, :break_joins, :lookup, keyword_init: true)

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
            when Ast::ConstantRead      then transfer_constant_read(node)
            when Ast::LocalVariableWrite then transfer_local_write(node, ctx)
            when Ast::Sequence           then transfer_sequence(node, ctx)
            when Ast::If                 then transfer_if(node, ctx)
            when Ast::Return             then transfer_return(node, ctx)
            when Ast::Break              then transfer_break(node, ctx)
            when Ast::Next               then transfer_next(node, ctx)
            when Ast::Redo               then @lattice.bottom
            when Ast::Retry              then @lattice.bottom
            when Ast::While              then transfer_while(node, ctx)
            when Ast::Until              then transfer_while(node, ctx)
            when Ast::ForLoop            then transfer_for_loop(node, ctx)
            when Ast::Case               then transfer_case(node, ctx)
            when Ast::And                then transfer_and_or(node, ctx)
            when Ast::Or                 then transfer_and_or(node, ctx)
            when Ast::MethodCall         then transfer_method_call(node, ctx)
            when Ast::IntrinsicCall      then transfer_intrinsic_call(node, ctx)
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

          # A Sequence is `stmt1; stmt2; ...; stmtN`. Every child is
          # walked (so their subtree types get cached) but the sequence's
          # own type is the LAST child's type — that's the value the
          # enclosing expression sees.
          #
          # Divergent trailing statements are correctly reflected: if
          # stmtN is a Return/Break/etc., the sequence type is ⊥, and
          # method-return joining takes the return_joins path instead.
          # An empty sequence types as nil (Ruby's empty-block value).
          def transfer_sequence(node, ctx)
            last = @lattice.nil_type
            (node.nodes || []).each { |child| last = walk(child, ctx) }
            last
          end

          # `break value` — inside a loop or block-catching frame,
          # contributes `value`'s type to the current break scope. The
          # expression itself is divergent (⊥); loops pop their scope
          # and join contributions into their own result type.
          #
          # If we're outside any break scope (bare Break in a method
          # body) that's a LocalJumpError at runtime — the value never
          # flows anywhere at compile time either, so ⊥ stands.
          def transfer_break(node, ctx)
            value_type = node.value_node ? walk(node.value_node, ctx) : @lattice.nil_type
            top = ctx.break_joins.last
            top << value_type if top
            @lattice.bottom
          end

          # `next value` — skips to the next iteration. Value flows to
          # the block's per-iteration return (relevant for `map` etc.)
          # but never to the enclosing loop/method result. Tier 1
          # doesn't type block returns yet, so drop the value; just
          # diverge.
          def transfer_next(node, ctx)
            walk(node.value_node, ctx) if node.value_node
            @lattice.bottom
          end

          # `while cond; body; end` and `until cond; body; end` both
          # return nil when they fall out normally. If the body breaks
          # with a value, that value becomes the loop's result — so we
          # push a fresh break scope, walk cond+body, then join nil
          # with the collected break contributions.
          def transfer_while(node, ctx)
            walk(node.condition_node, ctx)
            with_break_scope(ctx) do |contribs|
              walk(node.body_node, ctx)
              contribs.reduce(@lattice.nil_type) { |acc, t| @lattice.join(acc, t) }
            end
          end

          # `for x in collection; body; end` — Ruby returns the
          # collection when the loop completes normally, or the break
          # value if body breaks. The collection's own type is our
          # best result for the completed case; join in any break
          # contributions.
          def transfer_for_loop(node, ctx)
            coll_type = walk(node.collection_node, ctx)
            with_break_scope(ctx) do |contribs|
              walk(node.body_node, ctx)
              contribs.reduce(coll_type) { |acc, t| @lattice.join(acc, t) }
            end
          end

          # Push a fresh break_joins scope, run the block with the
          # empty contributions array, pop when done. Yields the
          # contributions to the block so it can compute the result.
          def with_break_scope(ctx)
            contribs = []
            ctx.break_joins.push(contribs)
            begin
              yield contribs
            ensure
              ctx.break_joins.pop
            end
          end

          # `a && b` returns `a` when `a` is falsy, else `b`.
          # `a || b` returns `a` when `a` is truthy, else `b`.
          # Either way the result type is a subset of LUB(left, right)
          # — Tier 1 uses the plain LUB and defers the "left cannot be
          # falsy" precision refinement to Tier-2 narrowing, which
          # needs a truthy/falsy carve-out on the lattice we haven't
          # committed to yet.
          def transfer_and_or(node, ctx)
            left_type = walk(node.left_node, ctx)
            right_type = walk(node.right_node, ctx)
            @lattice.join(left_type, right_type)
          end

          # `case subj; when a, b then body_ab; when c then body_c; else e; end`
          # — subject and all conditions are walked (their types cached
          # even though we don't use them at Tier 1). The case's type
          # is the join of every when-arm's body type with the else
          # body's type — or nullable if there's no else, since a
          # non-matching case with no else returns nil at runtime.
          def transfer_case(node, ctx)
            walk(node.subject_node, ctx) if node.subject_node
            arms = (node.whens || []).map do |w|
              (w.condition_nodes || []).each { |c| walk(c, ctx) }
              walk(w.body_node, ctx)
            end
            else_type = node.else_node ? walk(node.else_node, ctx) : @lattice.nil_type
            arms.reduce(else_type) { |acc, t| @lattice.join(acc, t) }
          end

          # Method-call return-type resolution. No distinction between
          # universe and user classes — everything TI cares about is
          # "does this class have a Ruby-body method entry for this name?"
          # Universe classes are just classes that happen to have some
          # methods that terminate in Intrinsics.foo (whose return types
          # come from INTRINSIC_RETURN_TYPES, not any universe-specific
          # annotation).
          #
          #   1. Walk the receiver's class-only ancestor chain (Ruby is
          #      single-inheritance for classes; module_flattening has
          #      already lowered module includes into per-class tables).
          #   2. First class C in the chain with @methods[[C, name]] set
          #      → look up C.name's return type via the engine.
          #   3. No hit → ⊤ (either method_missing at runtime or the
          #      method is a hand-coded override we haven't hoisted to
          #      Ruby yet — a de-intrinsification candidate).
          #
          # ⊤ / ⊥ / <boolean> receivers → ⊤ (Tier 1 can't split
          # <boolean> into TrueClass|FalseClass without cloning the call).
          def transfer_method_call(node, ctx)
            # Walk receiver + args + block so their types get cached.
            recv_type = node.receiver_node ? walk(node.receiver_node, ctx) : @lattice.concrete(ctx.class_flat)
            (node.arg_nodes || []).each { |a| walk(a, ctx) }
            walk(node.block_node, ctx) if node.block_node

            # Ruby's class-as-value primitives — `.new` and `.allocate`
            # break the "type-determines-dispatch" model because the
            # receiver's VALUE (which class) determines the return, not
            # its TYPE (Class). When the receiver AST is literally a
            # constant that resolves to a class we know, peek through
            # and return that class's instance type.
            #
            # This is monotone: the receiver's AST *shape* is fixed at
            # parse time, so the peek branch is chosen once and never
            # changes. Within it, the returned type is a compile-time
            # constant, independent of anything that flows through the
            # analysis.
            #
            # Falls through to the normal ancestor walk when receiver
            # isn't a constant — under Tier 1 that yields ⊤ via
            # Class#new's annotated return (currently ⊤). Recovering
            # precision through non-constant receivers needs dependent
            # `Class[X]` types — Tier 2+ extension.
            if (t = try_class_value_peek(node))
              return t
            end

            return @lattice.top if recv_type.top? || recv_type.bottom?
            recv_class = recv_type.concrete
            return @lattice.top if recv_class == :__boolean__

            resolve_method_call_return(recv_class, node.name, ctx)
          end

          CLASS_VALUE_METHODS = %i[new allocate].freeze
          private_constant :CLASS_VALUE_METHODS

          # Type of a bare constant reference. Under the "class-of-value"
          # rule, look up the constant's value in the top-level scope,
          # then return its class as the type:
          #
          #   X = 42        → value: IntegerObject → type = Integer
          #   Y = "hi"      → value: StringObject  → type = String
          #   INT = Integer → value: Integer class → type = Class
          #
          # Class-valued constants (`Integer`, `String`, `Foo`) all
          # collapse to `Class` under Tier 1. That precision loss is the
          # motivating case for the Class[X] lattice extension in Tier 2.
          # The AST-level peek in transfer_method_call already recovers
          # the common `.new` / `.allocate` construction pattern on bare
          # constant references without needing dependent types.
          #
          # Resolution is intentionally simple — top-level lookup only.
          # Lexical scope walking and nested paths (Foo::Bar) come when
          # we're typing programs that need them; the tighter rule
          # goes through Compiler::Reachability.resolve_const_to_flat.
          def transfer_constant_read(node)
            return @lattice.top if @top_level_scope.nil?
            val = (@top_level_scope.constants_table || {})[node.name.to_sym]
            return @lattice.top if val.nil?
            class_sym_of_value(val)
          end

          # Class-of-value primitive. A ClassObject's class is Class;
          # a plain ModuleObject's class is Module (Class is a subclass
          # of Module in Ruby); anything else uses its own class_object.
          # Falls back to ⊤ for unfamiliar Vm value types.
          def class_sym_of_value(val)
            if val.is_a?(Vm::ClassObject)
              @lattice.concrete(:Class)
            elsif val.is_a?(Vm::ModuleObject)
              @lattice.concrete(:Module)
            elsif val.respond_to?(:class_object) && val.class_object
              @lattice.concrete(Reachability.flat_name(val.class_object))
            else
              @lattice.top
            end
          end

          # If this call is `SomeClass.new(…)` / `SomeClass.allocate`
          # where SomeClass is a ConstantRead resolving to a known
          # class, return that class as the type. Otherwise nil (caller
          # falls through to normal dispatch).
          def try_class_value_peek(node)
            return nil unless CLASS_VALUE_METHODS.include?(node.name)
            recv = node.receiver_node
            return nil unless recv.is_a?(Ast::ConstantRead)
            class_sym = recv.name.to_sym
            # Simple resolver: top-level lookup only. Doesn't handle
            # lexical-scope shadowing or nested constants (Foo::Bar) —
            # extend when we start typing programs that need it.
            return nil unless @lattice.ancestor_chains.key?(class_sym)
            @lattice.concrete(class_sym)
          end

          # Walk the class-only ancestor chain from `recv_class` upward,
          # returning the first hit's return-type node value.
          def resolve_method_call_return(recv_class, method_name, ctx)
            chain = @lattice.ancestor_chains[recv_class] || [recv_class]
            chain.each do |cls|
              next unless @methods.key?([cls, method_name])
              return ctx.lookup.call(self.class.method_node(cls, method_name))
            end
            @lattice.top
          end

          # `Intrinsics.foo(...)` — Frozone's Ruby↔C++ membrane. The
          # return type comes from IntrinsicLowering::INTRINSIC_RETURN_TYPES,
          # the single annotation surface. Missing entry → ⊤ (safe
          # default; blocks narrowing chains and shows up as a
          # de-annotation candidate).
          def transfer_intrinsic_call(node, ctx)
            (node.param_nodes || []).each { |a| walk(a, ctx) }
            annotation = Backend::CppBox::IntrinsicLowering.return_type_of(node.name)
            annotation_to_type(annotation)
          end

          # Decode the INTRINSIC_RETURN_TYPES value shape into a lattice
          # Type. See the map's docstring for the shape reference.
          def annotation_to_type(annotation)
            return @lattice.top if annotation.nil?
            case annotation
            when Symbol
              case annotation
              when :__top__     then @lattice.top
              when :__boolean__ then @lattice.boolean_type
              else                    @lattice.concrete(annotation)
              end
            when Array
              # [Symbol, nullable: true] tail-hash-arg form
              class_sym, *opts = annotation
              nullable = opts.any? { |o| o.is_a?(Hash) && o[:nullable] }
              @lattice.concrete(class_sym, nullable: nullable)
            else
              @lattice.top
            end
          end
        end
      end
    end
  end
end
