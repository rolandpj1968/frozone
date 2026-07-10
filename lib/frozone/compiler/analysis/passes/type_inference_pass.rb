# Tier-1 type inference: concrete-class-only, flow-insensitive
# ("0-CFA over the class hierarchy"). Runs on the unified analysis
# engine.
#
# ------------------------------------------------------------------
# Node kinds
# ------------------------------------------------------------------
#
#   MethodNode(class_flat, method_name)
#     — value is the method's return type. This is the primary node
#       kind visible to the engine.
#   ParamNode(class_flat, method_name, param_name)
#     — value is the join of caller-pushed arg types for that
#       positional param. Populated by `push_param_types` at
#       callsites; consumed by the enclosing method's body transfer
#       via `env[pname] = lookup(param_node)`.
#
# Both are frozen Structs — field-based eql?/hash gives value
# equality automatically. Different Struct classes have distinct
# identity even when fields would overlap, which is what we want.
#
# Extension point for context-sensitive analysis (1-CFA type-context,
# see docs/analysis-framework-plan.md §4.8): adding a `context` field
# to either Struct differentiates contexts without changing the
# equality semantics. The engine's value map remains a flat
# Hash[Node → LatticeValue].
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
# For each MethodNode, walk C.methods_table[m]'s body:
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
          # Engine node keys. Struct-based so eql?/hash come by field
          # equality automatically, and different Struct classes are
          # distinct even when fields overlap. Frozen at construction —
          # safe as Hash keys, immutable across recomputes.
          MethodNode = Struct.new(:class_flat, :method_name) do
            def to_s = "MethodNode(#{class_flat}, #{method_name})"
            alias_method :inspect, :to_s
          end

          ParamNode = Struct.new(:class_flat, :method_name, :param_name) do
            def to_s = "ParamNode(#{class_flat}, #{method_name}, #{param_name})"
            alias_method :inspect, :to_s
          end

          def self.method_node(class_flat, method_name)
            MethodNode.new(class_flat.to_sym, method_name.to_sym).freeze
          end

          def self.param_node(class_flat, method_name, param_name)
            ParamNode.new(class_flat.to_sym, method_name.to_sym, param_name.to_sym).freeze
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
            @methods.each do |(cls_flat, mname), m|
              seeds[self.class.method_node(cls_flat, mname)] = @lattice.bottom
              each_pushable_param(m) do |pname|
                seeds[self.class.param_node(cls_flat, mname, pname)] = @lattice.bottom
              end
            end
            seeds
          end

          def transfer(node, _current, lookup)
            case node
            when MethodNode then transfer_method_node(node, lookup)
            when ParamNode  then transfer_param_node(node, lookup)
            else                 TransferResult::EMPTY
            end
          end

          private

          # Walk a method body → (return_type, pushes). Shared between
          # the MethodNode transfer (pull-side: publish return_type) and
          # the ParamNode transfer (push-side: bump owning MethodNode
          # when the param rises so it re-walks with the new env).
          def transfer_method_node(node, lookup)
            method = @methods[[node.class_flat, node.method_name]]
            return TransferResult::EMPTY unless method
            return_type, pushes = walk_method_body(node.class_flat, node.method_name, method, lookup)
            TransferResult.both(self_value: return_type, pushes: pushes)
          end

          # When a callsite raises a ParamNode, the engine enqueues it.
          # Its transfer here re-walks the owning method's body with the
          # fresh env and pushes the (possibly-higher) return type to
          # the owning MethodNode. That's what forwards the "params
          # changed, re-inspect me" signal to the engine — without it,
          # the method's cached return stays stale until something else
          # enqueues it.
          def transfer_param_node(node, lookup)
            method = @methods[[node.class_flat, node.method_name]]
            return TransferResult::EMPTY unless method
            return_type, pushes = walk_method_body(node.class_flat, node.method_name, method, lookup)
            # Merge our own return-type contribution into the pushes
            # for the owning MethodNode — that's what triggers a
            # re-transfer via apply_update's monotone-rise check.
            method_node = self.class.method_node(node.class_flat, node.method_name)
            prev = pushes[method_node]
            pushes[method_node] = prev ? @lattice.join(prev, return_type) : return_type
            TransferResult.push(pushes)
          end

          def walk_method_body(cls_flat, mname, method, lookup)
            ctx = TransferCtx.new(
              class_flat: cls_flat,
              method_name: mname,
              env:         {},
              return_joins: [],
              break_joins: [],
              lookup:      lookup,
              pushes:      {},
              narrowings:  {},
            )
            seed_params(method, ctx)
            terminal_type = walk(method.body, ctx)
            return_type = ctx.return_joins.reduce(terminal_type) { |acc, t| @lattice.join(acc, t) }
            # A ⊥ result is legitimate under the bipolar model: the
            # method hasn't been supplied any concrete param types yet
            # OR its callers themselves haven't converged. Do NOT
            # collapse to ⊤ — that would contaminate the return
            # permanently (⊤ ∪ Integer = ⊤ under a monotone lattice)
            # and defeat the whole point of callsite-driven refinement.
            # Callers that read a ⊥ return handle it via the receiver-
            # is-⊥ short-circuit in transfer_method_call.
            [return_type, ctx.pushes]
          end

          # `break_joins` — stack of Arrays, one per enclosing break-catching
          # scope (Wave-1 loops; later, blocks). `Break` pushes its value
          # type onto the top array; the loop transfer pops and joins the
          # collected values into its own result (a plain while returns
          # nil, but `while true; break 42; end` returns Integer).
          #
          # `narrowings` — active predicate narrowings by local-var name.
          # Reads consult this overlay first, falling back to env. Writes
          # invalidate any active narrowing on the written var (a write
          # changes what we know about it). Branch transfers push a fresh
          # narrowing on entry and restore the pre-branch snapshot on
          # exit — env accumulates writes normally either way, so flow-
          # insensitive semantics on writes is preserved.
          TransferCtx = Struct.new(:class_flat, :method_name, :env, :return_joins, :break_joins, :lookup, :pushes, :narrowings, keyword_init: true)

          NarrowingFact = Struct.new(:target_name, :truthy_type, :falsy_type)

          # Params eligible for callsite propagation. First-cut
          # constraint: no splat / kwargs / block-param, no optional
          # defaults. Yields each required-param name in order. Other
          # shapes still get env[pname] = ⊤ under seed_params.
          def each_pushable_param(method)
            return unless pushable_signature?(method)
            (method.required_params || []).each { |name| yield name }
          end

          def pushable_signature?(method)
            return false unless (method.required_params || []).all? { |p| p.is_a?(Symbol) }
            return false unless (method.optional_params || []).empty?
            return false if method.respond_to?(:rest_param) && method.rest_param
            return false if method.respond_to?(:required_kw_params) && !(method.required_kw_params || []).empty?
            return false if method.respond_to?(:optional_kw_params) && !(method.optional_kw_params || []).empty?
            return false if method.respond_to?(:kw_rest_param) && method.kw_rest_param
            return false if method.respond_to?(:block_param) && method.block_param
            true
          end

          # Params on pushable-shape methods get their types from the
          # engine — the ParamNode accumulates arg-type contributions
          # from every reachable callsite (see push_param_types).
          # Non-pushable-shape (splat/kwargs/block/optional-defaults)
          # methods still default to ⊤ because the push-side can't
          # safely attribute args to those slots.
          def seed_params(method, ctx)
            if pushable_signature?(method)
              (method.required_params || []).each do |name|
                ctx.env[name] = ctx.lookup.call(self.class.param_node(ctx.class_flat, ctx.method_name, name))
              end
            else
              (method.required_params || []).each { |name| ctx.env[name] = @lattice.top }
              (method.optional_params || []).each { |(name, _default)| ctx.env[name] = @lattice.top }
            end
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
            when Ast::ArrayLiteral      then transfer_literal_children(node, ctx, :Array)
            when Ast::HashLiteral       then transfer_literal_children(node, ctx, :Hash)
            when Ast::RangeLiteral      then transfer_literal_children(node, ctx, :Range)
            when Ast::RegexpLiteral     then @lattice.concrete(:Regexp)
            when Ast::InterpolatedRegexpLiteral then transfer_literal_children(node, ctx, :Regexp)
            when Ast::InterpolatedString then transfer_literal_children(node, ctx, :String)
            when Ast::SelfLiteral       then @lattice.concrete(ctx.class_flat)
            when Ast::LocalVariableRead then read_local(node.name, ctx)
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
            when Ast::Rescue             then transfer_rescue(node, ctx)
            when Ast::Super              then transfer_super(node, ctx)
            when Ast::Yield              then transfer_yield(node, ctx)
            when Ast::Lambda             then @lattice.concrete(:Proc)
            when Ast::MethodDef          then @lattice.concrete(:Symbol)
            when Ast::AttributeWrite     then transfer_attribute_write(node, ctx)
            when Ast::ConstantWrite      then transfer_pass_through_value(node, ctx)
            when Ast::MultipleAssignment then transfer_pass_through_value(node, ctx)
            when Ast::InstanceVariableWrite then transfer_pass_through_value(node, ctx)
            when Ast::ClassVariableWrite    then transfer_pass_through_value(node, ctx)
            when Ast::GlobalVariableWrite   then transfer_pass_through_value(node, ctx)
            when Ast::SplatArg           then walk(node.value_node, ctx)
            when Ast::BlockArg           then transfer_block_arg(node, ctx)
            when Ast::MatchWrite         then transfer_children_typed(node, ctx, :Integer, nullable: true)
            when Ast::DefinedExpr        then @lattice.concrete(:String, nullable: true)
            when Ast::DefinedConstant    then @lattice.concrete(:String, nullable: true)
            when Ast::FlipFlop           then transfer_children_typed(node, ctx, :__boolean__)
            when Ast::MethodAlias        then @lattice.nil_type
            when Ast::GlobalAlias        then @lattice.nil_type
            when Ast::ClassDef           then @lattice.top
            when Ast::ModuleDef          then @lattice.top
            when Ast::SingletonClassDef  then @lattice.top
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
            # A write invalidates any active predicate narrowing on this
            # var — subsequent reads inside the branch should see the
            # flow-insensitive env, not the stale narrow.
            ctx.narrowings.delete(node.name)
            rhs_type
          end

          # Reads see the narrowings overlay first (flow-sensitive branch
          # view) and fall back to env (flow-insensitive join of writes).
          def read_local(name, ctx)
            return ctx.narrowings[name] if ctx.narrowings.key?(name)
            ctx.env[name] || @lattice.top
          end

          def transfer_if(node, ctx)
            # Walk the predicate for its subtree types + return value.
            walk(node.pred_node, ctx)
            # Tier-2 narrowing: if the predicate is a canonical is_a? /
            # kind_of? / instance_of? / nil? call on a local variable,
            # its truthy and falsy arms see different types for that
            # local. The predicate-canonicity barf (#230) guarantees
            # these methods keep their standard semantics.
            fact = narrowing_fact(node.pred_node, ctx)
            then_type = with_narrowed(ctx, fact, :truthy) { walk(node.then_node, ctx) }
            else_type = with_narrowed(ctx, fact, :falsy) do
              node.else_node ? walk(node.else_node, ctx) : @lattice.nil_type
            end
            # Early-exit narrowing: if exactly one arm's terminal type
            # is divergent (⊥ or noreturn — Return / raise / etc.), the
            # code AFTER this If proceeds with the OTHER arm's narrowed
            # env. Install it now so downstream reads see it.
            install_surviving_narrowing(ctx, fact, then_type, else_type) if fact
            @lattice.join(then_type, else_type)
          end

          # After both arms walk, if exactly one arm is divergent, mutate
          # ctx.narrowings so the surviving arm's per-If-fact narrowing
          # persists. Both-diverge or both-survive: leave ctx.narrowings
          # at the pre-If snapshot (already restored by with_narrowed).
          #
          # `return if x.nil?; use_x` pattern: truthy arm is Return
          # (divergent), falsy arm survives with `x` narrowed to the
          # stripped-nullable type. Post-If we install that so `use_x`
          # sees the narrowed x.
          def install_surviving_narrowing(ctx, fact, then_type, else_type)
            truthy_diverges = then_type.divergent?
            falsy_diverges  = else_type.divergent?
            return if truthy_diverges == falsy_diverges  # both or neither
            surviving = truthy_diverges ? fact.falsy_type : fact.truthy_type
            ctx.narrowings[fact.target_name] = surviving
          end

          # Extract a NarrowingFact from a predicate expression, or nil
          # if the shape isn't recognisable. AST-level match — the hard-
          # predicate barf on the emitter path guarantees these method
          # names carry their canonical semantics whenever they resolve
          # via ancestor lookup.
          #
          # Supports:
          # - Simple: `x.is_a?(K)` / `x.kind_of?(K)` / `x.instance_of?(K)`
          #   / `x.nil?` — direct narrowing.
          # - Compound And: `p && q` — truthy narrowing = meet of both
          #   subfacts' truthy narrowings (only when both narrow the
          #   same target). Falsy: no reliable narrowing (Tier 2 skips).
          # - Compound Or: `p || q` — falsy narrowing = meet of both
          #   subfacts' falsy narrowings (only when both narrow the
          #   same target). Truthy: no reliable narrowing.
          def narrowing_fact(pred_node, ctx)
            case pred_node
            when Ast::MethodCall then narrowing_from_call(pred_node, ctx)
            when Ast::And        then narrowing_from_and(pred_node, ctx)
            when Ast::Or         then narrowing_from_or(pred_node, ctx)
            end
          end

          def narrowing_from_call(pred_node, ctx)
            recv = pred_node.receiver_node
            return nil unless recv.is_a?(Ast::LocalVariableRead)
            target = recv.name
            case pred_node.name
            when :is_a?, :kind_of?, :instance_of?
              args = pred_node.arg_nodes || []
              return nil unless args.size == 1
              class_sym = class_arg_flat_name(args[0])
              return nil unless class_sym
              build_class_narrow(target, class_sym, ctx)
            when :nil?
              args = pred_node.arg_nodes || []
              return nil unless args.empty?
              build_nil_narrow(target, ctx)
            end
          end

          def narrowing_from_and(node, ctx)
            left = narrowing_fact(node.left_node, ctx)
            right = narrowing_fact(node.right_node, ctx)
            combine_compound(left, right, side: :truthy, ctx: ctx)
          end

          def narrowing_from_or(node, ctx)
            left = narrowing_fact(node.left_node, ctx)
            right = narrowing_fact(node.right_node, ctx)
            combine_compound(left, right, side: :falsy, ctx: ctx)
          end

          # Combine two per-side narrowings on the SAME target. If they
          # disagree on the target, we skip (Tier-2 lattice can't
          # represent multi-target narrowings from one Fact yet).
          # `side` = :truthy for And (both must hold when compound is
          # truthy) or :falsy for Or (both must hold when compound is
          # falsy). The OTHER side gets `current` — no compound info.
          def combine_compound(left, right, side:, ctx:)
            return nil unless left && right
            return nil unless left.target_name == right.target_name
            target = left.target_name
            current = read_local(target, ctx)
            left_side  = side == :truthy ? left.truthy_type  : left.falsy_type
            right_side = side == :truthy ? right.truthy_type : right.falsy_type
            combined = lattice_meet(left_side, right_side)
            if side == :truthy
              NarrowingFact.new(target, combined, current)
            else
              NarrowingFact.new(target, current, combined)
            end
          end

          # Tier-1 meet primitive: greatest lower bound of two types.
          # If either subsumes the other, that's the meet. Otherwise
          # the intersection is empty → ⊥ (the compound is unsatisfiable
          # and this arm is unreachable).
          def lattice_meet(a, b)
            return a if @lattice.subsumes?(a, b)
            return b if @lattice.subsumes?(b, a)
            @lattice.bottom
          end

          # Only trust the class argument if it's a bare ConstantRead
          # naming a class in our lattice. Anything else (variable
          # reference, ConstantPath we haven't peeked through, arbitrary
          # expression) yields no fact — sound conservative fallback.
          def class_arg_flat_name(node)
            return nil unless node.is_a?(Ast::ConstantRead)
            name = node.name.to_sym
            @lattice.ancestor_chains.key?(name) ? name : nil
          end

          # `is_a?(K)` is true when the receiver's runtime class is K
          # or a descendant of K, false otherwise. Narrowing partitions
          # `current` into (truthy_arm, falsy_arm) by the same predicate.
          #
          # Split current into a non-null part (C) and a nil part (if
          # nullable). Analyze each independently against K, then
          # recombine.
          #
          # Non-null part C vs K:
          #   - C ⊑ K → all of C satisfies is_a?(K); truthy=C, falsy=⊥.
          #   - K ⊑ C → K is a proper subset of C; some of C satisfies.
          #     Truthy = K. Falsy would be "C minus K" — Tier-1 can't
          #     express set difference, keep C (sound but imprecise).
          #   - Disjoint → nothing in C satisfies; truthy=⊥, falsy=C.
          #
          # Nil part: nil satisfies is_a?(K) iff NilClass ⊑ K. If yes,
          # nil goes to the truthy arm; else it goes to the falsy arm.
          # Join back with the arm's non-null contribution.
          def build_class_narrow(target, class_sym, ctx)
            current = read_local(target, ctx)
            k_type = @lattice.concrete(class_sym)
            c_non_null = @lattice.concrete(current.concrete)
            if @lattice.subsumes?(c_non_null, k_type)
              truthy_non_null = c_non_null
              falsy_non_null  = @lattice.bottom
            elsif @lattice.subsumes?(k_type, c_non_null)
              truthy_non_null = k_type
              falsy_non_null  = c_non_null
            else
              truthy_non_null = @lattice.bottom
              falsy_non_null  = c_non_null
            end
            if current.nullable
              if @lattice.subsumes?(@lattice.nil_type, k_type)
                truthy = @lattice.join(truthy_non_null, @lattice.nil_type)
                falsy  = falsy_non_null
              else
                truthy = truthy_non_null
                falsy  = @lattice.join(falsy_non_null, @lattice.nil_type)
              end
            else
              truthy = truthy_non_null
              falsy  = falsy_non_null
            end
            NarrowingFact.new(target, truthy, falsy)
          end

          def build_nil_narrow(target, ctx)
            current = read_local(target, ctx)
            truthy = @lattice.nil_type
            falsy =
              if current.concrete == TypeLattice::NIL_CLASS && !current.nullable
                # Already exactly NilClass → falsy is unreachable.
                @lattice.bottom
              elsif current.nullable
                # Strip the nullable bit.
                @lattice.concrete(current.concrete, nullable: false)
              else
                # Non-nullable, non-nil concrete → falsy stays as is.
                current
              end
            NarrowingFact.new(target, truthy, falsy)
          end

          # Save narrowings, install the fact's per-arm type, run the
          # block, restore. Env writes made inside the block accumulate
          # to ctx.env unaffected — flow-insensitive semantics preserved
          # for reachability outside the arm.
          def with_narrowed(ctx, fact, arm)
            return yield unless fact
            saved = ctx.narrowings.dup
            new_type = arm == :truthy ? fact.truthy_type : fact.falsy_type
            ctx.narrowings[fact.target_name] = new_type
            begin
              yield
            ensure
              ctx.narrowings = saved
            end
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

          # `&proc_expr` in a call-site position. Transparent — the
          # BlockArg's own type is the wrapped expression's type
          # (usually Proc, sometimes Symbol via &:sym, sometimes nil).
          # Not the ⊤ default because the block-arg wrapping is
          # syntactic and TI can see through it.
          def transfer_block_arg(node, ctx)
            walk(node.value_node, ctx)
          end

          # Nodes whose subexpressions matter (walk their children so
          # subtree types get cached) but whose own type is a fixed
          # class annotation — MatchWrite (Regex match returns Integer
          # or nil), FlipFlop (synthetic boolean state).
          def transfer_children_typed(node, ctx, class_sym, nullable: false)
            walk_children(node, ctx)
            case class_sym
            when :__boolean__ then @lattice.boolean_type(nullable: nullable)
            else                   @lattice.concrete(class_sym, nullable: nullable)
            end
          end

          # `obj.foo = val` and `obj.foo=(a, b, val)` — Ruby returns
          # the last value in the arg list regardless of what the
          # setter itself returns. Safe-nav (`obj&.foo = val`) may
          # return nil when the receiver is nil.
          def transfer_attribute_write(node, ctx)
            walk(node.receiver_node, ctx) if node.receiver_node
            arg_types = (node.arg_nodes || []).map { |a| walk(a, ctx) }
            (node.kw_arg_nodes || []).each do |pair|
              # kw_arg_nodes is a list of [key_node, value_node] pairs.
              Array(pair).each { |n| walk(n, ctx) if n.is_a?(Ast::Node) }
            end
            base = arg_types.last || @lattice.nil_type
            node.instance_variable_get(:@safe_nav) ? @lattice.join(base, @lattice.nil_type) : base
          end

          # Assignments whose Ruby return value IS the RHS: ConstantWrite
          # (`C = val`), MultipleAssignment (`a, b = rhs` returns rhs).
          # walk() the value_node explicitly so we can return its type;
          # `walk_children` handles any siblings (namespace nodes,
          # target subtrees) so their types still land in the cache.
          def transfer_pass_through_value(node, ctx)
            value_type = walk(node.value_node, ctx)
            walk_children(node, ctx)
            value_type
          end

          # `super(args)` / `super` — resolves against the ancestor
          # chain starting from the class ABOVE the current method's
          # defining class (skips this class's own definition). Same
          # lookup mechanism as method_call, just seeded one step up.
          # No class above → ⊤ (BasicObject#foo super would raise
          # NoMethodError at runtime; TI stays conservative).
          def transfer_super(node, ctx)
            (node.arg_nodes || []).each { |a| walk(a, ctx) }
            walk(node.block_node, ctx) if node.block_node
            chain = @lattice.ancestor_chains[ctx.class_flat] || [ctx.class_flat]
            parent_chain = chain.drop(1)
            return @lattice.top if parent_chain.empty?
            parent_chain.each do |cls|
              next unless @methods.key?([cls, ctx.method_name])
              return ctx.lookup.call(self.class.method_node(cls, ctx.method_name))
            end
            @lattice.top
          end

          # `yield args` — dispatches to the block passed to the
          # enclosing method. Tier 1 doesn't track block bodies, so
          # the result is ⊤. Args still walked so their subtree types
          # get cached.
          def transfer_yield(node, ctx)
            (node.arg_nodes || []).each { |a| walk(a, ctx) }
            (node.kw_arg_nodes || {}).each_value { |v| walk(v, ctx) if v.is_a?(Ast::Node) }
            @lattice.top
          end

          # Composite literals whose value type is fixed (Range,
          # Regexp, interpolated String) but whose subexpressions
          # need walking so their own types land in the cache.
          def transfer_literal_children(node, ctx, class_sym)
            walk_children(node, ctx)
            @lattice.concrete(class_sym)
          end

          # `begin; body; rescue A => e; a_body; rescue B; b_body; else e_body; ensure ens; end`
          #
          # Two ways to leave with a value:
          #   1. No exception raised → body_type (or else_type if `else`
          #      is present — else replaces body's contribution).
          #   2. Any rescue clause matches → that clause's body_type.
          # Ensure runs on every exit but its value is discarded (unless
          # the ensure explicitly returns, which contributes to
          # return_joins via the Return transfer as usual).
          def transfer_rescue(node, ctx)
            body_type = walk(node.body, ctx)
            normal_type = node.else_node ? walk(node.else_node, ctx) : body_type
            clause_types = (node.rescue_clauses || []).map do |clause|
              (clause.exception_nodes || []).each { |ex| walk(ex, ctx) }
              walk(clause.assign_node, ctx) if clause.assign_node
              walk(clause.body, ctx)
            end
            walk(node.ensure_node, ctx) if node.ensure_node
            clause_types.reduce(normal_type) { |acc, t| @lattice.join(acc, t) }
          end

          # `case subj; when a, b then body_ab; when c then body_c; else e; end`
          # — subject and all conditions are walked (their types cached
          # even though we don't use them at Tier 1). The case's type
          # is the join of every when-arm's body type with the else
          # body's type — or nullable if there's no else, since a
          # non-matching case with no else returns nil at runtime.
          #
          # Tier-2 narrowing: when the subject is a local variable and
          # each when's conditions are all bare class references, each
          # when-arm body walks with the subject narrowed to the LUB of
          # those class types. Else-arm doesn't narrow (Tier-1 has no
          # negative narrow).
          def transfer_case(node, ctx)
            walk(node.subject_node, ctx) if node.subject_node
            target = case_narrow_target(node)
            arms = (node.whens || []).map do |w|
              (w.condition_nodes || []).each { |c| walk(c, ctx) }
              fact = case_arm_narrowing(target, w.condition_nodes, ctx)
              with_narrowed(ctx, fact, :truthy) { walk(w.body_node, ctx) }
            end
            else_type = node.else_node ? walk(node.else_node, ctx) : @lattice.nil_type
            arms.reduce(else_type) { |acc, t| @lattice.join(acc, t) }
          end

          # The subject of `case subj` must be a bare LocalVariableRead
          # to narrow. Subject-less case (`case; when cond then …`) has
          # no receiver to narrow.
          def case_narrow_target(node)
            subj = node.subject_node
            return nil unless subj.is_a?(Ast::LocalVariableRead)
            subj.name
          end

          # Build a NarrowingFact for a single when-arm's body. Requires
          # ALL of the arm's conditions to be bare class references
          # (LUB'd together to form the truthy narrowing). Otherwise nil.
          def case_arm_narrowing(target, conditions, ctx)
            return nil unless target
            return nil if (conditions || []).empty?
            class_types = conditions.map { |c| class_arg_flat_name(c) }
            return nil unless class_types.all?
            narrow = class_types.map { |sym| @lattice.concrete(sym) }
                                .reduce { |acc, t| @lattice.join(acc, t) }
            current = read_local(target, ctx)
            truthy = @lattice.subsumes?(current, narrow) ? current : narrow
            NarrowingFact.new(target, truthy, current)
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

            # Receiver is ⊥ or noreturn → the receiver expression itself
            # doesn't produce a value in the current iterate (either
            # unreached, or provably diverges). The call inherits the
            # same divergent state — no downstream code sees a return.
            # Pushing ⊤ from an unreached/divergent callsite would
            # permanently poison every param on the target under
            # monotone joins.
            return recv_type if recv_type.divergent?

            # Receiver-cone dispatch: the receiver's static type covers
            # a set of possible dynamic classes (⊤ = all classes,
            # <boolean> = TrueClass ∪ FalseClass, concrete C = C plus
            # descendants of C in the closed-world reachable set). The
            # call's return is the LUB across every class in the cone
            # of that class's resolution of `method_name`. Under
            # closed-world this is bounded — bo.nil? types as <boolean>
            # because every class's nil? returns TrueClass or FalseClass,
            # bo.to_s types as String, etc. — not ⊤.
            dispatch_across_cone(recv_type, node.name, ctx, node.arg_nodes || [])
          end

          # Compute LUB of `method_name`'s resolutions across the
          # receiver's type cone. Under closed-world every ctx.lookup
          # call inside also records a dep, so per-target rises re-
          # enqueue this transfer for a fresh LUB.
          #
          # Naive form is O(|cone| × |chain|) — each S walks its full
          # ancestor chain looking for `method_name` (and, if missing,
          # walks again for `method_missing`). Under single-inheritance
          # most S's in a cone SHARE their first-hit class (they all
          # inherit T's method because none of them override) — so we
          # dedup by first-hit class and lookup once per distinct hit.
          #
          # Three buckets per receiver S in cone:
          #   direct  — some class C ∈ S's chain defines `method_name`;
          #             resolution is C's return-type node.
          #   mm      — no direct hit; some class M ∈ S's chain (non-
          #             BasicObject) defines `method_missing`; resolution
          #             is M's method_missing return.
          #   noreturn — no direct hit AND no user mm on chain; falls
          #              through to BasicObject#method_missing (annotated
          #              :__noreturn__).
          def dispatch_across_cone(recv_type, method_name, ctx, arg_nodes)
            cone = receiver_type_cone(recv_type)
            return @lattice.top if cone.empty?

            direct_hits    = Set.new
            mm_hits        = Set.new
            noreturn_falls = false
            cone.each do |s|
              chain = @lattice.ancestor_chains[s] || [s]
              direct = chain.find { |c| @methods.key?([c, method_name]) }
              if direct
                direct_hits << direct
              else
                mm = chain.find { |c| c != :BasicObject && @methods.key?([c, :method_missing]) }
                mm ? (mm_hits << mm) : (noreturn_falls = true)
              end
            end

            result = @lattice.bottom
            direct_hits.each do |c|
              push_param_types(c, method_name, arg_nodes, ctx) if arg_nodes
              result = @lattice.join(result, ctx.lookup.call(self.class.method_node(c, method_name)))
            end
            mm_hits.each do |c|
              result = @lattice.join(result, ctx.lookup.call(self.class.method_node(c, :method_missing)))
            end
            result = @lattice.join(result, @lattice.noreturn) if noreturn_falls
            result
          end

          # The set of concrete classes a receiver's static type could
          # bind to at runtime under closed-world. Every non-⊤, non-
          # <boolean> class expands via the lattice-precomputed descendant
          # set (which includes the class itself) so a receiver typed as
          # `Numeric` covers Integer + Float + Rational + Complex, etc.
          # Under closed-world this is bounded and cheap — the lattice
          # freezes the inversion of ancestor_chains once at pass init.
          #
          # Nullable receivers (T?, <boolean>?) add NilClass — at runtime
          # the receiver might be nil, in which case dispatch resolves
          # on NilClass. Without this, `x&.foo` and even naive `x.foo`
          # on a nullable would ignore the nil path — usually noreturn
          # (NoMethodError), but sometimes concrete (nil.nil? → true).
          # ⊤ already covers NilClass so nullable-⊤ is a no-op.
          def receiver_type_cone(recv_type)
            if recv_type.top?
              @lattice.ancestor_chains.keys
            elsif recv_type.boolean_synth?
              recv_type.nullable ? %i[TrueClass FalseClass NilClass] : %i[TrueClass FalseClass]
            else
              descs = @lattice.descendants[recv_type.concrete]
              base = descs && !descs.empty? ? descs.to_a : [recv_type.concrete]
              recv_type.nullable ? base + [:NilClass] : base
            end
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
          # returning the first hit's return-type node value. Also
          # pushes call arg types to the resolved target's param nodes
          # (via `arg_nodes`) so the callee's env picks them up on its
          # next transfer.
          def resolve_method_call_return(recv_class, method_name, ctx, arg_nodes: nil)
            chain = @lattice.ancestor_chains[recv_class] || [recv_class]
            chain.each do |cls|
              next unless @methods.key?([cls, method_name])
              push_param_types(cls, method_name, arg_nodes, ctx) if arg_nodes
              return ctx.lookup.call(self.class.method_node(cls, method_name))
            end
            resolve_missing_method(chain, ctx)
          end

          # Not found on the ancestor chain — Ruby routes to
          # method_missing on the same receiver. Two cases:
          #
          # 1. A user class in the chain (non-BasicObject) overrides
          #    method_missing. Its analyzed return type propagates via
          #    `ctx.lookup` — the dep-tracking (#248) fires on rise so
          #    this transfer re-runs as the mm's fixpoint tightens.
          #
          # 2. Otherwise the resolution falls through to
          #    BasicObject#method_missing, whose canonical body is
          #    `Intrinsics.basic_object_method_missing(...)` — annotated
          #    :__noreturn__. Short-circuit directly to noreturn.
          #
          # The barf-on-hard-override machinery (#230) doesn't cover
          # method_missing yet — a user could shadow it with a returning
          # body. We take that override's return type at face value.
          def resolve_missing_method(chain, ctx)
            chain.each do |cls|
              next if cls == :BasicObject
              next unless @methods.key?([cls, :method_missing])
              return ctx.lookup.call(self.class.method_node(cls, :method_missing))
            end
            @lattice.noreturn
          end

          # Push each positional-arg's inferred type into the target
          # method's ParamNode. Guarded by
          # pushable_signature? on the callee AND exact arity match:
          # if the callsite's shape doesn't cleanly map arg[i] → param[i]
          # for every required param, we skip — a mis-attributed push
          # would silently widen every param on every subsequent call.
          def push_param_types(cls, method_name, arg_nodes, ctx)
            m = @methods[[cls, method_name]]
            return unless m && pushable_signature?(m)
            required = m.required_params || []
            return unless arg_nodes.size == required.size
            return if arg_nodes.any? { |a| a.is_a?(Ast::SplatArg) || a.is_a?(Ast::BlockArg) || a.is_a?(Ast::ForwardBlock) }
            required.each_with_index do |pname, i|
              arg_type = @per_node_types[arg_nodes[i]] || @lattice.top
              node = self.class.param_node(cls, method_name, pname)
              prev = ctx.pushes[node]
              ctx.pushes[node] = prev ? @lattice.join(prev, arg_type) : arg_type
            end
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
              when :__top__      then @lattice.top
              when :__boolean__  then @lattice.boolean_type
              when :__noreturn__ then @lattice.noreturn
              else                     @lattice.concrete(annotation)
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
