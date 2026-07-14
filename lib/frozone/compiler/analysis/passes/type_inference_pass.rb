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
          # Analysis context. Under 0-CFA, every callee is analyzed
          # in one context; UNIT is that context, a frozen empty
          # tuple. Under 1-CFA type-context, the tuple carries the
          # caller-side (self_type, arg_types...) — see
          # docs/analysis-framework-plan.md §4.8. Same lattice, wider
          # key space; classifier decides per-method whether to widen
          # beyond UNIT.
          UNIT_CONTEXT = [].freeze

          # Engine node keys. Struct-based so eql?/hash come by field
          # equality automatically, and different Struct classes are
          # distinct even when fields overlap. Frozen at construction —
          # safe as Hash keys, immutable across recomputes.
          MethodNode = Struct.new(:class_flat, :method_name, :context) do
            def to_s
              base = "MethodNode(#{class_flat}, #{method_name})"
              context.empty? ? base : "#{base}@#{context.inspect}"
            end
            alias_method :inspect, :to_s
          end

          ParamNode = Struct.new(:class_flat, :method_name, :param_name, :context) do
            def to_s
              base = "ParamNode(#{class_flat}, #{method_name}, #{param_name})"
              context.empty? ? base : "#{base}@#{context.inspect}"
            end
            alias_method :inspect, :to_s
          end

          # Ivar-typing key. Class-scoped (not per-context): under
          # Ruby, ivars are per-instance shared storage, so a class
          # C's ivar @x is one node regardless of which method wrote
          # it. `home_class_flat` is the topmost class in C's ancestor
          # chain that mentions :@x (mirrors emitter's collect_ivars
          # + collect_parent_ivars — same storage-owning-class
          # semantics). Ivars from included modules attribute to the
          # topmost including class in the chain via the eager
          # ivar-home pass.
          IVarNode = Struct.new(:home_class_flat, :ivar_name) do
            def to_s = "IVarNode(#{home_class_flat}, #{ivar_name})"
            alias_method :inspect, :to_s
          end

          def self.method_node(class_flat, method_name, context = UNIT_CONTEXT)
            MethodNode.new(class_flat.to_sym, method_name.to_sym, context).freeze
          end

          def self.param_node(class_flat, method_name, param_name, context = UNIT_CONTEXT)
            ParamNode.new(class_flat.to_sym, method_name.to_sym, param_name.to_sym, context).freeze
          end

          def self.ivar_node(home_class_flat, ivar_name)
            IVarNode.new(home_class_flat.to_sym, ivar_name.to_sym).freeze
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
            # Widening tracker — per (class_flat, method_name), the set
            # of contexts materialized so far. Once a method exceeds
            # PER_METHOD_CONTEXT_CAP, further callsites fold to UNIT
            # for that target. Bounds combinatorial blowup while
            # preserving useful 1-CFA precision on the ~4% of methods
            # that actually benefit (see splat oracle empirics).
            @method_contexts = Hash.new { |h, k| h[k] = Set.new }
            # Diagnostic: trace every callee-context resolution.
            # FROZONE_TI_1CFA_TRACE=1 to enable. Output is pipe-
            # delimited (grep/sort friendly) to $stderr, capped at
            # FROZONE_TI_1CFA_TRACE_CAP lines (default 200000) so a
            # runaway loop doesn't fill the disk.
            @trace_contexts = ENV['FROZONE_TI_1CFA_TRACE'] == '1'
            @trace_cap = (ENV['FROZONE_TI_1CFA_TRACE_CAP'] || '200000').to_i
            @trace_count = 0
            # Growing set of classes TI has "encountered" via type
            # production. Cone iteration intersects with this set —
            # ⊤-receiver dispatch only fans out to classes we've
            # actually seen. Grows monotonically as walk() memoises
            # types. Class hierarchy is a fixed queryable oracle
            # (snapshot); this tracks which of its members TI has
            # touched.
            #
            # Bootstrap: Object + BasicObject (always reachable as
            # ancestors of everything), plus the Nil/True/False
            # singletons which are values pass consumers observe
            # ubiquitously.
            @seen_classes = Set.new(%i[Object BasicObject NilClass TrueClass FalseClass])
            # Track reached intrinsics for diagnostic. Two hashes:
            # counts per intrinsic name, and a set of names whose
            # return_type_of came back nil (unannotated). Unannotated
            # reached intrinsics are direct de-⊤-ification candidates.
            @reached_intrinsics = Hash.new(0)
            @unannotated_intrinsics = Set.new
            # Ivar-home cache: key (class_flat, ivar_name) → home
            # class_flat. Populated once by precompute_ivar_homes.
            # Read at InstanceVariableRead/Write time to route to
            # the shared IVarNode.
            @ivar_home = {}
            precompute_ivar_homes
            # Wide-cone diagnostic: counts callsites that hit the
            # dispatch_widened fallback under 1-CFA. Key is
            # [method_name, cone_size, recv_type_string], value is
            # hit count. Exposed via `wide_cone_hits` for dumper.
            @wide_cone_hits = Hash.new(0)
          end

          def lattice = @lattice

          # Type accessor for callers (emitter, tests). Nil for AST nodes
          # the pass never visited (unreachable methods, or nodes outside
          # any method body).
          def type_of(node) = @per_node_types[node]

          # Growing set of classes TI has encountered as a produced
          # Type value. Consumers query .size to detect whether an
          # engine.run round grew the set (needing an outer re-run).
          def seen_class_count = @seen_classes.size
          def seen_classes = @seen_classes

          # Intrinsic reach diagnostics. `reached_intrinsics` is a
          # Hash[name → call_count]; `unannotated_intrinsics` is the
          # subset with no INTRINSIC_RETURN_TYPES entry (return ⊤ by
          # default). Reached-but-unannotated names are de-⊤-ification
          # candidates — each is potentially cheap precision recovery.
          def reached_intrinsics = @reached_intrinsics
          def unannotated_intrinsics = @unannotated_intrinsics
          def wide_cone_hits = @wide_cone_hits

          # LUB across every context-specific MethodNode return for
          # (class_flat, method_name) in an engine values map. Useful
          # for consumers that don't discriminate by context (emitter
          # diagnostics, coarse-grained tests).
          #
          # Note: this is NOT 0-CFA-equivalent — LUB-of-transfers is
          # strictly finer than transfer-of-LUB under monotonicity, so
          # a consumer that used to see e.g. `Numeric` from a 0-CFA
          # widened analysis may now see `Float`. That's a precision
          # gain, not a regression.
          def method_return_widened(values, class_flat, method_name)
            cls_sym = class_flat.to_sym
            mname_sym = method_name.to_sym
            values.reduce(@lattice.bottom) do |acc, (k, v)|
              next acc unless k.is_a?(MethodNode) && k.class_flat == cls_sym && k.method_name == mname_sym
              @lattice.join(acc, v)
            end
          end

          # FROZONE_TI_ENTRY_ONLY=1 seeds only the synthetic entry
          # method. Everything else materializes on demand as
          # dispatch_across_cone resolves callsites (via
          # dispatch_lookup priming with NORETURN → engine enqueues
          # the callee's transfer). Under this mode, reachability of
          # methods, contexts, and classes is TI-directed — a method
          # is analyzed iff some transfer's dispatch resolves to it.
          # Anything not called (by name or dispatch) from the entry's
          # transitive closure stays unanalyzed. See memory
          # [[project_ti_subsumes_reachability]] for the direction.
          ENTRY_ONLY_SEED = ENV['FROZONE_TI_ENTRY_ONLY'] == '1'

          def seed
            return entry_only_seed if ENTRY_ONLY_SEED
            seeds = {}
            @methods.each do |(cls_flat, mname), m|
              seeds[self.class.method_node(cls_flat, mname)] = @lattice.bottom
              each_pushable_param(m) do |pname|
                seeds[self.class.param_node(cls_flat, mname, pname)] = @lattice.bottom
              end
            end
            seeds
          end

          # Seed only the synthetic entry method. Consumers should feed
          # @methods a `[[:Object, :__entry__]] => SyntheticEntryMethod`
          # entry — dispatch_across_cone drives the rest via the
          # NORETURN prime.
          def entry_only_seed
            entry_node = self.class.method_node(:Object, :__entry__)
            return {} unless @methods.key?([:Object, :__entry__])
            { entry_node => @lattice.bottom }
          end

          def transfer(node, _current, lookup)
            case node
            when MethodNode then transfer_method_node(node, lookup)
            when ParamNode  then transfer_param_node(node, lookup)
            else                 TransferResult::EMPTY
            end
          end

          # Ivar-home lookup. Given a class C and ivar name :@x, returns
          # the flat-name Symbol of the topmost class in C's ancestor
          # chain that mentions :@x — matches the emitter's storage-owning
          # class semantics. Falls back to C itself if no ancestor
          # mentions it (means C is the topmost mentioner).
          def ivar_home_for(class_flat, ivar_name)
            @ivar_home[[class_flat.to_sym, ivar_name.to_sym]] || class_flat.to_sym
          end

          private

          # Eager preliminary pass — build the ivar-home map once at
          # pass init. Two phases:
          #
          # 1. direct_mentions[K]: for each K (class OR module) in
          #    @methods, scan the method bodies for ivar names.
          # 2. effective_mentions[C] for each Class C: direct_mentions[C]
          #    UNION direct_mentions[M] for every module M in
          #    C.ancestors_list. Transitive includes come free from
          #    Ruby's MRO putting all transitively-included modules
          #    in ancestors_list.
          # 3. ivar_home[(C, :@x)] = topmost class X_i in C's
          #    class-only ancestor chain where :@x is in
          #    effective_mentions[X_i]. Modules can't own storage
          #    per Ruby, so homing always lands on a class.
          #
          # Depends only on syntactic mentions across the FULL method
          # table — stable, unaffected by reached-set growth.
          def precompute_ivar_homes
            direct = Hash.new { |h, k| h[k] = Set.new }
            @methods.each do |(class_flat, _mname), method|
              next unless method&.body
              scan_ivar_mentions(method.body, direct[class_flat])
            end

            effective = {}
            @lattice.all_classes.each do |cls_flat, cls_obj|
              next unless cls_obj.is_a?(Vm::ClassObject)
              mentions = Set.new(direct[cls_flat])
              cls_obj.ancestors_list.each do |anc|
                next if anc.equal?(cls_obj)
                next if anc.is_a?(Vm::ClassObject)
                anc_flat = Reachability.flat_name(anc)
                mentions.merge(direct[anc_flat]) if anc_flat && direct.key?(anc_flat)
              end
              effective[cls_flat] = mentions
            end

            # For each (class, ivar) pair, walk the class ancestor chain
            # topward, home = topmost ancestor whose effective_mentions
            # includes the ivar.
            effective.each do |cls_flat, ivars|
              chain = @lattice.ancestor_chains[cls_flat] || [cls_flat]
              ivars.each do |ivar|
                home = cls_flat
                chain.each do |anc_flat|
                  next unless effective[anc_flat]&.include?(ivar)
                  home = anc_flat
                end
                @ivar_home[[cls_flat, ivar]] = home
              end
            end
          end

          # AST walk to collect ivar names (as Symbols like :@x) from
          # InstanceVariableRead / InstanceVariableWrite anywhere in the
          # body (including nested blocks, if/case branches, rescue,
          # etc.). Blocks-in-methods are Ruby-level closures so their
          # ivar mentions still count.
          def scan_ivar_mentions(node, out)
            return unless node.is_a?(Ast::Node)
            case node
            when Ast::InstanceVariableRead, Ast::InstanceVariableWrite
              out << node.name.to_sym
            end
            node.children.each { |c| scan_ivar_mentions(c, out) } if node.respond_to?(:children)
          end

          # Walk a method body → (return_type, pushes). Shared between
          # the MethodNode transfer (pull-side: publish return_type) and
          # the ParamNode transfer (push-side: bump owning MethodNode
          # when the param rises so it re-walks with the new env).
          def transfer_method_node(node, lookup)
            method = @methods[[node.class_flat, node.method_name]]
            return TransferResult::EMPTY unless method
            return_type, pushes = walk_method_body(node.class_flat, node.method_name, method, lookup, context: node.context)
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
            return_type, pushes = walk_method_body(node.class_flat, node.method_name, method, lookup, context: node.context)
            # Merge our own return-type contribution into the pushes
            # for the owning MethodNode — that's what triggers a
            # re-transfer via apply_update's monotone-rise check.
            method_node = self.class.method_node(node.class_flat, node.method_name, node.context)
            prev = pushes[method_node]
            pushes[method_node] = prev ? @lattice.join(prev, return_type) : return_type
            TransferResult.push(pushes)
          end

          def walk_method_body(cls_flat, mname, method, lookup, context: UNIT_CONTEXT)
            ctx = TransferCtx.new(
              class_flat: cls_flat,
              method_name: mname,
              context:     context,
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
          TransferCtx = Struct.new(:class_flat, :method_name, :context, :env, :return_joins, :break_joins, :lookup, :pushes, :narrowings, keyword_init: true)

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
            # Optional positional AND optional kwarg params are pushable
            # too — callsites push when the arg is supplied; seed_params
            # walks the default expression to seed the "no arg supplied,
            # default fires at runtime" case. LUB gives sound answer.
            #
            # Still bail on rest / kw-rest / block-param — those need
            # structural aggregate typing (splat authenticity, block-body
            # walk) not yet implemented.
            return false if method.respond_to?(:rest_param) && method.rest_param
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
                ctx.env[name] = ctx.lookup.call(self.class.param_node(ctx.class_flat, ctx.method_name, name, ctx.context))
              end
              # Optional positionals: LUB "callsite pushed if supplied"
              # (ParamNode) with "default fires at runtime if omitted"
              # (walk the default expression in dependency order —
              # earlier params are already in env, so `def foo(a, b = a + 1)`
              # walks b's default with env[:a] bound).
              (method.optional_params || []).each do |(name, default_node)|
                pushed = ctx.lookup.call(self.class.param_node(ctx.class_flat, ctx.method_name, name, ctx.context))
                default_type = default_node ? walk(default_node, ctx) : @lattice.nil_type
                ctx.env[name] = @lattice.join(pushed, default_type)
              end
              # Required kwargs bind to method-locals with the kwarg
              # name; seed from the same ParamNode key that
              # push_kwarg_types pushes to.
              if method.respond_to?(:required_kw_params) && method.required_kw_params
                method.required_kw_params.each do |kw_name|
                  ctx.env[kw_name] = ctx.lookup.call(self.class.param_node(ctx.class_flat, ctx.method_name, kw_name, ctx.context))
                end
              end
              # Optional kwargs: same pattern as optional positionals.
              if method.respond_to?(:optional_kw_params) && method.optional_kw_params
                method.optional_kw_params.each do |(kw_name, default_node)|
                  pushed = ctx.lookup.call(self.class.param_node(ctx.class_flat, ctx.method_name, kw_name, ctx.context))
                  default_type = default_node ? walk(default_node, ctx) : @lattice.nil_type
                  ctx.env[kw_name] = @lattice.join(pushed, default_type)
                end
              end
            else
              (method.required_params || []).each { |name| ctx.env[name] = @lattice.top }
              (method.optional_params || []).each { |(name, _default)| ctx.env[name] = @lattice.top }
              if method.respond_to?(:required_kw_params) && method.required_kw_params
                method.required_kw_params.each { |kw_name| ctx.env[kw_name] = @lattice.top }
              end
              if method.respond_to?(:optional_kw_params) && method.optional_kw_params
                method.optional_kw_params.each { |(kw_name, _default)| ctx.env[kw_name] = @lattice.top }
              end
            end
            ctx.env[method.rest_param] = @lattice.concrete(:Array) if method.respond_to?(:rest_param) && method.rest_param
          end

          # Type of any AST expression. Result is memoised in the per-node
          # map both for the emitter's benefit and for cheap re-visits.
          # Under 1-CFA the same AST node can be walked in multiple
          # contexts as different callers trigger the enclosing method's
          # transfer — LUB-merge into @per_node_types so type_of returns
          # the sound-widened answer across all contexts. The current
          # walk's own return value is `t` (not the LUB) so it doesn't
          # contaminate the CURRENT context's transfer with unrelated
          # contexts' contributions.
          def walk(node, ctx)
            return @lattice.top if node.nil?
            t = compute(node, ctx)
            note_seen_from_type(t)
            prev = @per_node_types[node]
            @per_node_types[node] = prev ? @lattice.join(prev, t) : t
            t
          end

          # Register the type's concrete class in @seen_classes.
          # Called from every walk() call — types produced anywhere in
          # the transfer walk get registered. Skips synthetic markers.
          def note_seen_from_type(t)
            @seen_classes.add(:NilClass) if t.nullable
            case t.concrete
            when :__bottom__, :__top__, :__noreturn__ then nil
            when :__boolean__
              @seen_classes.add(:TrueClass)
              @seen_classes.add(:FalseClass)
            else
              @seen_classes.add(t.concrete)
            end
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
            when Ast::SelfLiteral       then ctx.context.empty? ? @lattice.concrete(ctx.class_flat) : ctx.context.first
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
            when Ast::InstanceVariableRead  then transfer_ivar_read(node, ctx)
            when Ast::InstanceVariableWrite then transfer_ivar_write(node, ctx)
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

          # `@x = value` — walk the RHS, push its type to the shared
          # IVarNode(home, :@x) so all sibling methods that read @x see
          # the value flow, and return the RHS type as the assignment
          # expression's value (matches `x = 5` returning 5).
          def transfer_ivar_write(node, ctx)
            value_type = walk(node.value_node, ctx)
            return value_type if value_type.divergent?
            home = ivar_home_from_ctx(ctx, node.name)
            return value_type unless home
            ivar_node = self.class.ivar_node(home, node.name)
            prev = ctx.pushes[ivar_node]
            ctx.pushes[ivar_node] = prev ? @lattice.join(prev, value_type) : value_type
            value_type
          end

          # `@x` — read from IVarNode(home, :@x). Layer NilClass on top:
          # Ruby's default-nil semantic means a read of an ivar never
          # written on this path returns nil (silently). The lattice's
          # join(NilClass, T) = T? does exactly this. No smartness
          # about proving write-before-read on this path (that's a
          # flow-sensitive follow-on; not needed for correctness).
          def transfer_ivar_read(node, ctx)
            home = ivar_home_from_ctx(ctx, node.name)
            return @lattice.top unless home
            ivar_node = self.class.ivar_node(home, node.name)
            @lattice.join(@lattice.nil_type, ctx.lookup.call(ivar_node))
          end

          # Resolve the ivar's home class from the current transfer
          # context. Ivars are per-instance storage, so the home is
          # determined by the RECEIVER's class, not by which class or
          # module owns the method being walked.
          #
          # Under 1-CFA context, self's type comes from ctx.context.first
          # (matches SelfLiteral resolution). If self's concrete is a
          # known class, home via ivar_home_for. Otherwise (⊤ / synthetic
          # boolean / etc.), bail — the ivar can't be attributed to any
          # single home, so we return nil and callers fall back to ⊤/
          # skip the push.
          #
          # For methods keyed on a class (not module) with no 1-CFA
          # context, fall back to ctx.class_flat — the caller-class IS
          # the receiver's class in that case.
          def ivar_home_from_ctx(ctx, ivar_name)
            self_type = ctx.context.empty? ? @lattice.concrete(ctx.class_flat) : ctx.context.first
            return nil unless self_type
            return nil if self_type.top? || self_type.boolean_synth?
            recv_flat = self_type.concrete
            return nil if recv_flat == :__top__ || recv_flat == :__boolean__ ||
                          recv_flat == :__bottom__ || recv_flat == :__noreturn__
            ivar_home_for(recv_flat, ivar_name)
          end

          # `super(args)` / `super` — resolves against the ancestor
          # chain starting from the class ABOVE the current method's
          # defining class (skips this class's own definition). Same
          # lookup mechanism as method_call, just seeded one step up.
          # No class above → ⊤ (BasicObject#foo super would raise
          # NoMethodError at runtime; TI stays conservative).
          def transfer_super(node, ctx)
            arg_nodes = node.arg_nodes || []
            arg_nodes.each { |a| walk(a, ctx) }
            walk(node.block_node, ctx) if node.block_node
            chain = @lattice.ancestor_chains[ctx.class_flat] || [ctx.class_flat]
            parent_chain = chain.drop(1)
            return @lattice.top if parent_chain.empty?
            arg_types = arg_nodes.map { |a| @per_node_types[a] || @lattice.top }
            self_type = ctx.context.empty? ? @lattice.concrete(ctx.class_flat) : ctx.context.first
            callee_context = [self_type, *arg_types].freeze
            parent_chain.each do |cls|
              next unless @methods.key?([cls, ctx.method_name])
              cap_context, action = context_for_target(cls, ctx.method_name, callee_context)
              trace_context(ctx, cls, ctx.method_name, callee_context, cap_context, action)
              push_param_types(cls, ctx.method_name, arg_nodes, ctx, cap_context)
              return dispatch_lookup(cls, ctx.method_name, cap_context, ctx)
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
            # Strict evaluation: if any arg (or block) walk yields a
            # divergent type, the whole call diverges — Ruby evaluates
            # args left-to-right BEFORE dispatch, so a diverging arg
            # means the receiver's method never runs. Under our lattice
            # ⊥ / NORETURN both mean "no value produced," so a call
            # depending on such an expression is itself divergent.
            #
            # This is the load-bearing fix for the coerce-protocol
            # cascade: `self.__coerce_op__(v, :+)` in the falsy arm of
            # `v.is_a?(Integer)` has v narrowed to ⊥, and this rule
            # collapses the entire dispatch — Numeric#__coerce_op__ is
            # never analyzed from that path.
            arg_nodes = node.arg_nodes || []
            arg_nodes.each do |a|
              t = walk(a, ctx)
              return t if t.divergent?
            end
            # Kwargs / kw-splat / block: also walked strictly so their
            # types cache and any divergent value collapses the call.
            (node.kw_arg_nodes || []).each do |(_key, value_node)|
              t = walk(value_node, ctx)
              return t if t.divergent?
            end
            (node.kw_splat_nodes || []).each do |k|
              t = walk(k, ctx)
              return t if t.divergent?
            end
            if node.block_node
              t = walk(node.block_node, ctx)
              return t if t.divergent?
            end

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
            if (t = try_class_value_peek(node, ctx))
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
            dispatch_across_cone(recv_type, node.name, ctx, node.arg_nodes || [], kw_arg_nodes: node.kw_arg_nodes, kw_splat_nodes: node.kw_splat_nodes)
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
          # Under 1-CFA type-context each receiver in the cone forms its
          # own callee context, so the 0-CFA-style dedup by defining
          # class no longer applies — two receivers that inherit the
          # same body still analyze it separately when their receiver
          # types differ. Iterate the cone directly and construct
          # callee_context per receiver.
          #
          # Widening cap: if the cone is wider than CONE_WIDEN_THRESHOLD
          # (e.g. an Object receiver → hundreds of descendants) the
          # per-receiver contexts would explode combinatorially. Fall
          # back to UNIT context for the callsite — all cone entries
          # share the UNIT MethodNode/ParamNode, joining LUB-style
          # (0-CFA behavior). Loses the receiver-class precision on
          # wide-cone dispatches but keeps termination and cost
          # bounded. Small cones (Integer + a handful of descendants,
          # tap/dup receivers) stay per-context precise.
          CONE_WIDEN_THRESHOLD = (ENV['FROZONE_TI_CONE_WIDEN'] || '8').to_i.then { |n| n <= 0 ? Float::INFINITY : n }
          # Empirical measurement: cap disabled to observe the natural
          # fanout under 1-CFA. Wide-cone dedup still bounds the hot
          # loop; per-method fanout is now driven purely by callsite
          # diversity.
          PER_METHOD_CONTEXT_CAP = Float::INFINITY
          # Env-var kill-switch: FROZONE_TI_1CFA=0 forces UNIT context
          # at every callsite (pure 0-CFA). Useful for debugging blowup
          # and for A/B measurement against 1-CFA under identical
          # analysis. Default on (1-CFA).
          ONE_CFA_ENABLED = ENV['FROZONE_TI_1CFA'] != '0'

          # Pick a context for calling (target_cls, target_method) —
          # either the candidate (if we haven't blown the per-method
          # cap yet) or UNIT (if we have). Registers the candidate on
          # first sight so subsequent identical callsites still use
          # it. Once the cap is hit, further NEW contexts fold to UNIT.
          # Returns [result_context, action_tag] where action_tag is
          # UNIT / REUSE / NEW / CAP-FOLD. Trace-friendly.
          def context_for_target(target_cls, target_method, candidate)
            return [candidate, 'UNIT'] if candidate.equal?(UNIT_CONTEXT)
            seen = @method_contexts[[target_cls, target_method]]
            return [candidate, 'REUSE'] if seen.include?(candidate)
            if seen.size >= PER_METHOD_CONTEXT_CAP
              return [UNIT_CONTEXT, 'CAP-FOLD']
            end
            seen << candidate
            [candidate, 'NEW']
          end

          # Emit a pipe-delimited trace line for one context resolution.
          # Shape:
          #   ti1cfa|<seq>|<caller_cls>#<caller_m>|<target_cls>#<target_m>|<action>|<candidate>|<result>
          # Enabled by FROZONE_TI_1CFA_TRACE=1. Capped by
          # FROZONE_TI_1CFA_TRACE_CAP (default 200000).
          def trace_context(ctx, target_cls, target_method, candidate, result, action)
            return unless @trace_contexts
            @trace_count += 1
            return if @trace_count > @trace_cap
            $stderr.puts "ti1cfa|#{@trace_count}|#{ctx.class_flat}##{ctx.method_name}|#{target_cls}##{target_method}|#{action}|#{candidate.inspect}|#{result.inspect}"
          end

          # Walk Ruby's authentic MRO (via the interpreter's
          # `ancestors_list` — prepends + self + includes + superclass,
          # recurse; classes AND modules) starting at `cls_flat` and
          # return the flat-name of the first ancestor that defines
          # `method_name` in @methods. `exclude` (used for the
          # method_missing route) skips a specific class.
          #
          # MRO comes from the interpreter (authoritative). Membership
          # comes from @methods (TI's method table, which specs
          # populate independently of the ClassObject's methods_table).
          def resolve_method_owner(cls_flat, method_name, exclude: nil)
            cls = @lattice.all_classes[cls_flat]
            return nil unless cls
            cls.ancestors_list.each do |anc|
              flat = Reachability.flat_name(anc)
              next if flat.nil? || flat == exclude
              return flat if @methods.key?([flat, method_name])
            end
            nil
          end

          def dispatch_across_cone(recv_type, method_name, ctx, arg_nodes, kw_arg_nodes: nil, kw_splat_nodes: nil)
            cone = receiver_type_cone(recv_type)
            return @lattice.top if cone.empty?
            widen = !ONE_CFA_ENABLED || cone.size > CONE_WIDEN_THRESHOLD
            @wide_cone_hits[[method_name, cone.size, recv_type.to_s]] += 1 if widen && ONE_CFA_ENABLED
            return dispatch_widened(cone, method_name, ctx, arg_nodes, kw_arg_nodes: kw_arg_nodes, kw_splat_nodes: kw_splat_nodes) if widen
            arg_types = arg_nodes ? arg_nodes.map { |a| @per_node_types[a] || @lattice.top } : []
            result = @lattice.bottom
            cone.each do |s|
              candidate = [@lattice.concrete(s), *arg_types].freeze
              direct = resolve_method_owner(s, method_name)
              if direct
                callee_context, action = context_for_target(direct, method_name, candidate)
                trace_context(ctx, direct, method_name, candidate, callee_context, action)
                push_param_types(direct, method_name, arg_nodes, ctx, callee_context, kw_arg_nodes: kw_arg_nodes, kw_splat_nodes: kw_splat_nodes) if arg_nodes
                result = @lattice.join(result, dispatch_lookup(direct, method_name, callee_context, ctx))
              else
                mm = resolve_method_owner(s, :method_missing, exclude: :BasicObject)
                if mm
                  mm_context, action = context_for_target(mm, :method_missing, candidate)
                  trace_context(ctx, mm, :method_missing, candidate, mm_context, action)
                  result = @lattice.join(result, dispatch_lookup(mm, :method_missing, mm_context, ctx))
                else
                  result = @lattice.join(result, @lattice.noreturn)
                end
              end
            end
            result
          end

          # Wide-cone / kill-switch path: dedup by defining class
          # (0-CFA-style) so we only pay one dispatch per distinct
          # target regardless of cone size. All lookups land at UNIT
          # context. Reproduces the pre-1-CFA hot loop.
          def dispatch_widened(cone, method_name, ctx, arg_nodes, kw_arg_nodes: nil, kw_splat_nodes: nil)
            direct_hits    = Set.new
            mm_hits        = Set.new
            noreturn_falls = false
            cone.each do |s|
              direct = resolve_method_owner(s, method_name)
              if direct
                direct_hits << direct
              else
                mm = resolve_method_owner(s, :method_missing, exclude: :BasicObject)
                mm ? (mm_hits << mm) : (noreturn_falls = true)
              end
            end
            result = @lattice.bottom
            direct_hits.each do |c|
              push_param_types(c, method_name, arg_nodes, ctx, UNIT_CONTEXT, kw_arg_nodes: kw_arg_nodes, kw_splat_nodes: kw_splat_nodes) if arg_nodes
              trace_context(ctx, c, method_name, UNIT_CONTEXT, UNIT_CONTEXT, 'UNIT')
              result = @lattice.join(result, dispatch_lookup(c, method_name, UNIT_CONTEXT, ctx))
            end
            mm_hits.each do |c|
              trace_context(ctx, c, :method_missing, UNIT_CONTEXT, UNIT_CONTEXT, 'UNIT')
              result = @lattice.join(result, dispatch_lookup(c, :method_missing, UNIT_CONTEXT, ctx))
            end
            result = @lattice.join(result, @lattice.noreturn) if noreturn_falls
            result
          end

          # Look up the callee's MethodNode return AND prime it with
          # NORETURN so the specific-context transfer gets enqueued. Under
          # 0-CFA the seed already enqueued MethodNode(C, m, UNIT); under
          # 1-CFA a specific context is materialised on demand at this
          # callsite and needs an explicit trigger. NORETURN is
          # join-identity with any real type, so priming it doesn't
          # contaminate the eventual return — the transfer's actual
          # result replaces it monotonically.
          def dispatch_lookup(cls, method_name, callee_context, ctx)
            key = self.class.method_node(cls, method_name, callee_context)
            ctx.pushes[key] ||= @lattice.noreturn
            ctx.lookup.call(key)
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
          # Cone iteration intersects with @seen_classes — we only
          # dispatch to classes TI has already encountered as a produced
          # type somewhere. Bootstraps from Object/BasicObject/Nil/True
          # /FalseClass and grows monotonically. The outer engine.run
          # loop must re-run whenever @seen_classes has grown (or a
          # per-class SeenNode dep can drive it more precisely).
          def receiver_type_cone(recv_type)
            base =
              if recv_type.top?
                @lattice.ancestor_chains.keys
              elsif recv_type.boolean_synth?
                recv_type.nullable ? %i[TrueClass FalseClass NilClass] : %i[TrueClass FalseClass]
              else
                descs = @lattice.descendants[recv_type.concrete]
                d = descs && !descs.empty? ? descs.to_a : [recv_type.concrete]
                recv_type.nullable ? d + [:NilClass] : d
              end
            base & @seen_classes.to_a
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
          #
          # For ClassObject / ModuleObject values, also carry the
          # class's flat-name as the type's `value` narrowing —
          # `Foo` in code types as `Class[Foo]`, not just `Class`. Any
          # downstream widening (LUB with a different class value,
          # nullable induction) drops the value naturally.
          def class_sym_of_value(val)
            if val.is_a?(Vm::ClassObject)
              @lattice.concrete(:Class, value: Reachability.flat_name(val))
            elsif val.is_a?(Vm::ModuleObject)
              @lattice.concrete(:Module, value: Reachability.flat_name(val))
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
          #
          # For `.new`, also route through the class's `initialize`:
          # push call arg types to `[class, :initialize]`'s ParamNode
          # and read its MethodNode (adds a dep so this transfer re-runs
          # as initialize's fixpoint tightens). This is what makes
          # initialize actually WALKED at all — without it TI never sees
          # the class's ivar-first-writes, and IVarNode-typing (WIP)
          # would stay stuck at ⊥.
          #
          # `.allocate` explicitly does NOT route through initialize —
          # its whole purpose is to bypass it.
          def try_class_value_peek(node, ctx)
            return nil unless CLASS_VALUE_METHODS.include?(node.name)
            recv = node.receiver_node
            return nil unless recv.is_a?(Ast::ConstantRead)
            class_sym = recv.name.to_sym
            # Simple resolver: top-level lookup only. Doesn't handle
            # lexical-scope shadowing or nested constants (Foo::Bar) —
            # extend when we start typing programs that need it.
            return nil unless @lattice.ancestor_chains.key?(class_sym)
            route_new_to_initialize(class_sym, node.arg_nodes || [], ctx, kw_arg_nodes: node.kw_arg_nodes, kw_splat_nodes: node.kw_splat_nodes) if node.name == :new
            @lattice.concrete(class_sym)
          end

          # `SomeClass.new(args)` → walk SomeClass#initialize (or the
          # nearest ancestor that defines it — usually
          # BasicObject#initialize as a no-op). Pushes arg types to the
          # target's ParamNodes and adds a dep on its MethodNode so
          # this transfer re-fires as initialize's fixpoint tightens.
          #
          # If no `initialize` exists anywhere in the class chain,
          # nothing to do. Return type is discarded — the caller has
          # already committed to returning the constructed instance's
          # class, not initialize's return value.
          def route_new_to_initialize(class_sym, arg_nodes, ctx, kw_arg_nodes: nil, kw_splat_nodes: nil)
            chain = @lattice.ancestor_chains[class_sym] || [class_sym]
            chain.each do |cls|
              next unless @methods.key?([cls, :initialize])
              push_param_types(cls, :initialize, arg_nodes, ctx, UNIT_CONTEXT, kw_arg_nodes: kw_arg_nodes, kw_splat_nodes: kw_splat_nodes)
              ctx.lookup.call(self.class.method_node(cls, :initialize))
              return
            end
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
          # Push each arg type into the callee's specific-context
          # ParamNode. Guarded on pushable_signature? + exact arity —
          # mis-attributed pushes silently widen all params on the
          # target under monotone joins.
          #
          # No UNIT double-push: LUB across specific contexts (via
          # `method_return_widened`) is what consumers get when they
          # want a coarse summary. It's strictly finer than the 0-CFA
          # equivalent (LUB-of-transfers ⊑ transfer-of-LUB by
          # monotonicity), which is a precision win — the extra
          # information falls out of running the analyses separately.
          def push_param_types(cls, method_name, arg_nodes, ctx, callee_context = UNIT_CONTEXT, kw_arg_nodes: nil, kw_splat_nodes: nil)
            m = @methods[[cls, method_name]]
            return unless m && pushable_signature?(m)
            required = m.required_params || []
            optional = m.optional_params || []
            return unless arg_nodes.size >= required.size && arg_nodes.size <= required.size + optional.size
            return if arg_nodes.any? { |a| a.is_a?(Ast::SplatArg) || a.is_a?(Ast::BlockArg) || a.is_a?(Ast::ForwardBlock) }
            required.each_with_index do |pname, i|
              push_one(cls, method_name, pname, arg_nodes[i], ctx, callee_context)
            end
            # Positional optionals: callsite may supply 0..optional.size
            # of them. Push whichever were actually supplied — the rest
            # get their default via seed_params.
            optional.each_with_index do |(pname, _default), i|
              arg_node = arg_nodes[required.size + i]
              break unless arg_node
              push_one(cls, method_name, pname, arg_node, ctx, callee_context)
            end
            push_kwarg_types(cls, method_name, m, kw_arg_nodes, kw_splat_nodes, ctx, callee_context)
          end

          def push_one(cls, method_name, pname, arg_node, ctx, callee_context)
            arg_type = @per_node_types[arg_node] || @lattice.top
            node = self.class.param_node(cls, method_name, pname, callee_context)
            prev = ctx.pushes[node]
            ctx.pushes[node] = prev ? @lattice.join(prev, arg_type) : arg_type
          end

          # Push required-kwarg values from the callsite to the callee's
          # ParamNode(cls, method, kwarg_name, callee_context). Kwargs
          # bind to method locals with the same name inside the body,
          # so seed_params reads them via the SAME ParamNode as
          # positionals — no separate KwargNode needed.
          #
          # Phase 1 discipline (matches pushable_signature? gate):
          # - Callsite bails on **splat (kwargs unknown at compile time).
          # - Callee has ONLY required_kw_params (no optional_kw, no
          #   kw_rest). Enforced by pushable_signature?.
          # - Callsite must supply every required kwarg; else miss →
          #   runtime ArgumentError so no push should happen.
          # - kw_arg_nodes[i][0] must be a SymbolLiteral (so we know
          #   the kwarg name statically).
          #
          # kw_arg_nodes is `[[key_node, value_node], ...]` per the
          # Ast::MethodCall interface.
          def push_kwarg_types(cls, method_name, m, kw_arg_nodes, kw_splat_nodes, ctx, callee_context)
            return if kw_splat_nodes && !kw_splat_nodes.empty?
            required_kw = (m.respond_to?(:required_kw_params) ? m.required_kw_params : nil) || []
            optional_kw = (m.respond_to?(:optional_kw_params) ? m.optional_kw_params : nil) || []
            return if required_kw.empty? && optional_kw.empty?
            # Extract statically-known kwarg names + value types from the
            # callsite. Empty kw_arg_nodes is fine when required_kw is
            # empty (all-optional callee, callsite omitted all).
            supplied = {}
            (kw_arg_nodes || []).each do |(key_node, value_node)|
              return unless key_node.is_a?(Ast::SymbolLiteral)
              supplied[key_node.value.to_sym] = value_node
            end
            # Callsite must cover every callee-required kwarg — else
            # runtime ArgumentError, no dispatch happens.
            return unless required_kw.all? { |kw| supplied.key?(kw) }
            required_kw.each do |kw_name|
              push_one(cls, method_name, kw_name, supplied[kw_name], ctx, callee_context)
            end
            # Optional kwargs: push if supplied. Skip if omitted — the
            # default fires at runtime and seed_params walks it.
            optional_kw.each do |(kw_name, _default)|
              next unless supplied.key?(kw_name)
              push_one(cls, method_name, kw_name, supplied[kw_name], ctx, callee_context)
            end
          end

          # `Intrinsics.foo(...)` — Frozone's Ruby↔C++ membrane. The
          # return type comes from IntrinsicLowering::INTRINSIC_RETURN_TYPES,
          # the single annotation surface. Missing entry → ⊤ (safe
          # default; blocks narrowing chains and shows up as a
          # de-annotation candidate).
          def transfer_intrinsic_call(node, ctx)
            # Strict-eval short-circuit — matches transfer_method_call.
            # Divergent arg → whole call diverges (never reached at
            # runtime because arg evaluation blew up first).
            #
            # First param is the receiver by Frozone's intrinsic
            # calling convention. Save its type so we can resolve the
            # `:__self__` sigil (receiver-preserving intrinsics like
            # freeze / dup / <<) without walking it a second time.
            recv_type = nil
            (node.param_nodes || []).each_with_index do |a, i|
              t = walk(a, ctx)
              return t if t.divergent?
              recv_type = t if i == 0
            end
            @reached_intrinsics[node.name] += 1
            # AoT semantic bright line: at execute time, class/method/
            # constant/singleton tables are frozen and there is no Ruby
            # compiler; intrinsics that mutate the class graph or eval
            # dynamic code MUST raise. Independent of implementation
            # status — semantically noreturn under closed-world AoT.
            # Unimplemented-but-implementable intrinsics stay annotated
            # with their proper return type so the analysis reflects
            # semantics, not accidents of current build state.
            return @lattice.noreturn if Backend::CppBox::IntrinsicLowering.aot_forbidden?(node.name)
            annotation = Backend::CppBox::IntrinsicLowering.return_type_of(node.name)
            @unannotated_intrinsics << node.name if annotation.nil?
            return recv_type || @lattice.top if annotation == :__self__
            annotation_to_type(annotation)
          end

          # Decode the INTRINSIC_RETURN_TYPES value shape into a lattice
          # Type. See the map's docstring for the shape reference.
          # `:__self__` is NOT handled here — it's receiver-sensitive
          # and resolved at the call site in transfer_intrinsic_call.
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
