# Box-first C++ backend — Cpp string generators.
#
# Pure-function counterpart to the Emitter writers. Every method here
# produces a cpp string for an AST node — never touches a buffer or
# emits anything. Writers (in expr_emitter, class_emitter, etc.) call
# `cpp.from_X(node, locals)` for the inline expression bits and use
# their own `emit.line` / `emit.indented` to commit multi-line
# structures.
#
# Cpp is a class (not a module) because compilation context
# (user_classes / user_constants registries) is encapsulated as
# instance state — set once at compilation start, doesn't change. The
# Emitter holds the Cpp instance; writers reach it via `emit.cpp`.
#
# Per-call context (locals scope) stays as method args — it changes
# constantly as we walk into nested scopes.

require_relative 'runtime/universe'
require_relative 'method_emitter'
require_relative 'intrinsic_lowering'
require_relative 'integer_cache'
require_relative 'string_escape'
require_relative 'constant_resolver'
require_relative 'lambda_emitter'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Cpp
          # Raised at emission time when we encounter a Ruby pattern we
          # don't yet handle, OR a closed-world violation (constant we
          # can't statically resolve). Eager fail: better to halt the
          # build with a precise message than to silently emit nil and
          # produce a wrong binary.
          class EmissionError < StandardError; end

          # File-level decomposition mixins. Each contributes a related
          # cluster of methods (and constants) that share Cpp instance
          # state (@int_literals, @raw_int_arrays, @user_classes,
          # @user_constants, @method_scope, @emit) — kept as instance
          # methods so call sites stay unchanged. See the matching
          # files alongside this one.
          include IntegerCache
          include StringEscape
          include ConstantResolver
          include LambdaEmitter

          # Ruby operator → C++ vtable method name. Box-first can't use
          # operator overloading because every value is a pointer
          # (`a + b` would mean pointer arithmetic), so we route through
          # named virtuals on BasicObject's derived classes.
          # Operator → cpp_name. Uses the `op_` prefix (NOT `m_`)
          # so a Ruby `def plus` → `op_plus` can't collide with `:+
          # → op_plus`. Identifier methods always encode as
          # `m_<name>`; operator methods always as `op_<symbolic>`.
          # Two non-overlapping namespaces.
          OP_NAMES = {
            # Arithmetic
            :+   => "op_plus",  :-   => "op_minus",
            :*   => "op_mul",   :**  => "op_pow",
            :/   => "op_div",   :%   => "op_mod",
            # Comparison
            :<   => "op_lt",    :>   => "op_gt",
            :<=  => "op_le",    :>=  => "op_ge",
            :==  => "op_eq_q",  :!=  => "op_ne_q",
            :"<=>" => "op_spaceship",
            :=== => "op_case_eq",
            :=~  => "op_match_op",
            :!~  => "op_no_match",
            # Bitwise / shift
            :&   => "op_bit_and",
            :|   => "op_bit_or",
            :^   => "op_bit_xor",
            :~   => "op_bit_not",
            :<<  => "op_lshift",
            :>>  => "op_rshift",
            # Unary
            :!   => "op_not",
            :"-@" => "op_neg",
            :"+@" => "op_pos",
            # Indexing
            :[]  => "op_aref",
            :[]= => "op_aset",
            # Other Kernel-level methods with non-identifier names
            :"`" => "op_backtick",
          }.freeze

          # Ruby method name → C++ identifier. Operators go through
          # OP_NAMES; non-identifier suffixes (`?`, `!`, `=`) get a
          # distinct PREFIX (`mm_`) plus a kind SUFFIX (`_q`, `_bang`,
          # `_eq`). The dual marker — different prefix AND different
          # suffix from plain methods — keeps the encoding fully
          # injective: a Ruby method literally named `foo_q` encodes
          # to `m_foo_q` (singular `m_`), distinct from the predicate
          # `foo?` → `mm_foo_q` (doubled `mm_`).
          #
          #   Ruby `foo`    → `m_foo`         (plain)
          #   Ruby `foo?`   → `mm_foo_q`      (predicate)
          #   Ruby `foo!`   → `mm_foo_bang`   (bang)
          #   Ruby `foo=`   → `mm_foo_eq`     (setter)
          #
          # See spec/frozone/compiler/backend/cpp_box/method_name_spec.rb
          # for the exhaustive round-trip + collision tests.
          def self.method_name(ruby_name)
            return OP_NAMES[ruby_name] if OP_NAMES.key?(ruby_name)
            s = ruby_name.to_s
            return "mm_#{s.chomp('?')}_q"    if s.end_with?('?')
            return "mm_#{s.chomp('!')}_bang" if s.end_with?('!')
            return "mm_#{s.chomp('=')}_eq"   if s.end_with?('=')
            "m_#{s}"
          end

          # Shadowed-method slot name. Each ancestor method that's
          # shadowed by a higher-priority def in MRO order gets emitted
          # under this name on the host class so `super` can dispatch
          # into it. Origin is a Vm::ModuleObject (or ClassObject) —
          # never `:self` (the `:self` body lives at `m_X`).
          def self.shadowed_method_name(ruby_name, origin)
            base = method_name(ruby_name).sub(/^m_/, '')
            origin_flat = origin.full_name.to_s.gsub("::", "_")
            "sm_#{base}__from_#{origin_flat}"
          end

          # Wrap a sequence of C++ statements plus a final value expression
          # into a single C++ expression. The shape is controlled by
          # `FROZONE_BOX_BLOCK_EXPR_FORM` (default: `iile`):
          #   - `iile`: `([&]() -> #{type} { stmt1; stmt2; return v; }())`
          #     — portable, captures by reference, gcc inlines under -O2.
          #   - `stmt_expr`: `({ stmt1; stmt2; v; })`
          #     — gcc/clang statement expression. No closure, but is a
          #     gcc extension and disallows C++ `return` for early exit
          #     inside the block.
          # `stmts` may contain semicolons (each element is one C++
          # statement string). `value_expr` must NOT end in `;`.
          # Use this for STRAIGHT-LINE blocks: declarations + side-effects
          # + a single final value. For early-return shapes, use
          # `block_expr_with_returns` (TODO) or restructure as a ternary.
          def self.block_expr(stmts, value_expr, type: 'BO*')
            joined = stmts.empty? ? '' : "#{stmts.join(' ')} "
            case block_expr_form
            when :stmt_expr
              "({ #{joined}static_cast<#{type}>(#{value_expr}); })"
            else
              "([&]() -> #{type} { #{joined}return #{value_expr}; }())"
            end
          end

          # Form to use for `block_expr`. Default is `stmt_expr` (gcc
          # statement expressions — no closure overhead, ~4% smaller
          # generated source, straighter C++ that future block-inlining
          # and TI-driven specialization passes can work with directly).
          # Set `FROZONE_BOX_BLOCK_EXPR_FORM=iile` to opt back into the
          # original self-invoking-lambda form (portable C++17, useful
          # for debugging a suspected stmt_expr regression). Cached per
          # process — the env var is read once at startup.
          def self.block_expr_form
            @block_expr_form ||= case ENV['FROZONE_BOX_BLOCK_EXPR_FORM']
                                 when 'iile' then :iile
                                 else :stmt_expr
                                 end
          end

          # Multi-stage block expression with conditional early returns.
          # Each `phases[0..-2]` entry is a hash with:
          #   - `stmts:` — array of C++ statements to execute on entering
          #     the stage.
          #   - `early_return:` — `{ cond:, value: }` — if `cond` is true
          #     after the stage's stmts, yield `value` and skip the
          #     remaining stages.
          # The final `phases[-1]` entry has `stmts:` + `value:` (the
          # fallback value when no early-return condition fired).
          #
          # Forms:
          # - `iile`: linear `if (cond1) return v1; ... if (condN) return vN;
          #     fallback_stmts; return fallback_value;`. Side effects in
          #     stage K's stmts only run if all earlier conds were false.
          # - `stmt_expr`: nested ternary chain — each stage's early-return
          #     is `cond ? v : (next stage as stmt-expr)`. Side effects
          #     remain conditional because they live inside the false-arm
          #     stmt-expr.
          #
          # Mandatory: side effects in stage K's stmts must NOT execute
          # when an earlier stage's early-return fires. The nested-ternary
          # form satisfies this: the inner stmt-expr is only evaluated in
          # the false arm of the outer ternary.
          def self.staged_block_expr(phases, type: 'BO*')
            case block_expr_form
            when :stmt_expr
              last = phases.last
              inner = last[:stmts].empty? ? "(#{last[:value]})" : "({ #{last[:stmts].join(' ')} #{last[:value]}; })"
              phases[0..-2].reverse_each do |phase|
                setup = phase[:stmts].empty? ? '' : "#{phase[:stmts].join(' ')} "
                er = phase[:early_return]
                inner = "({ #{setup}#{er[:cond]} ? static_cast<#{type}>(#{er[:value]}) : static_cast<#{type}>(#{inner}); })"
              end
              inner
            else
              parts = []
              phases[0..-2].each do |phase|
                parts += phase[:stmts]
                er = phase[:early_return]
                parts << "if (#{er[:cond]}) return #{er[:value]};"
              end
              parts += phases.last[:stmts]
              parts << "return #{phases.last[:value]};"
              "([&]() -> #{type} { #{parts.join(' ')} }())"
            end
          end

          # Wrap a try/catch in expression position. `try_expr` is the
          # value-yielding expression for the success path; `catch_expr`
          # is the value-yielding expression for the matched-exception
          # path. `exception_decl` is the C++ exception declarator
          # (e.g. `BreakException& e_`, `Exception* e_`, `...`).
          #   - `iile`: `[&]() -> BO* { try { return T; } catch (D) { return C; } }()`
          #   - `stmt_expr`: `({ BO* _r; try { _r = T; } catch (D) { _r = C; } _r; })`
          # The stmt_expr form drops the closure overhead. The temp is
          # needed because both paths yield a value into the surrounding
          # expression context.
          def self.try_catch_expr(try_expr, exception_decl, catch_expr)
            case block_expr_form
            when :stmt_expr
              "({ BO* _r; try { _r = #{try_expr}; } catch (#{exception_decl}) { _r = #{catch_expr}; } _r; })"
            else
              "([&]() -> BO* { try { return #{try_expr}; } catch (#{exception_decl}) { return #{catch_expr}; } }())"
            end
          end

          # Wrap a sequence of statements that ends in a `throw` (or a
          # noreturn-call like `raise_private_call(...)`) into a
          # `BO*`-typed expression. The throw/noreturn never
          # returns, so there's no need for the caller to use the value.
          #   - `iile`: `([&]() -> BO* { stmts }())` (no return —
          #     the lambda still has type `BO*` because the
          #     declared return type wins).
          #   - `stmt_expr`: `({ stmts nil_instance(); })` — gcc's
          #     stmt-expr types as its last expression, which is `void`
          #     for a bare `throw;`. Append a `nil_instance()` sentinel
          #     to give the construct a `BO*` type, matching
          #     the codegen's standard "no useful value" idiom (cf.
          #     missing-else branches that lower to `else { nil_instance(); }`).
          #     The trailing `nil_instance()` load is unreachable —
          #     compilers fold it under -O1+ noreturn/throw analysis.
          def self.throw_expr(stmts)
            joined = stmts.empty? ? '' : "#{stmts.join(' ')} "
            case block_expr_form
            when :stmt_expr
              "({ #{joined}nil_instance(); })"
            else
              "([&]() -> BO* { #{joined}}())"
            end
          end

          # Nodes that produce a value usable in expression position.
          # Statement-only nodes don't get wrapped in implicit-return;
          # they handle their own control flow or have void value.
          # Ast::If and Ast::Case ARE expression-valid (Ruby's if/case
          # return the taken branch's value) — emitted as ternary or
          # lambda+early-return in expression position, multi-line in
          # statement position.
          def self.expression_node?(node)
            case node
            when Ast::Return, Ast::Sequence, Ast::While, Ast::Until,
                 Ast::Break, Ast::Next then false
            else true
            end
          end

          attr_reader :user_classes, :user_constants
          # Set by Emitter after construction. Needed by from_rescue to
          # render nested-lambda bodies via emit.capture + write_body.
          # Pure-functional otherwise — only the rescue path reaches back.
          attr_accessor :emit
          # Lexical scope chain (outermost-first) of the method currently
          # being emitted. Drives Ruby-style constant lookup: when a
          # method in `Parser::Base` references `Diagnostic::Engine`,
          # we try `Parser::Base::Diagnostic::Engine`, then
          # `Parser::Diagnostic::Engine`, then `Diagnostic::Engine`.
          # Empty list for the top-level body.
          attr_accessor :method_scope
          # Super-call resolution context. Populated by the override
          # emitter for the duration of one method body. Shape:
          #   { host_name: "Array",
          #     method_name: :any?,
          #     origin_index: 0,            # position in the chain
          #     chain: [[origin, method], ...] }
          # Ast::Super walks chain from origin_index+1 onwards to find
          # its target slot. nil outside an override-body emission.
          attr_accessor :super_context
          # Set of local-variable NAMES (as Strings) that are captured
          # by an inner Block/Lambda within the currently-emitting
          # scope. Captured locals are emitted as heap-allocated cells
          # (`BO** l_x = gc_box<BO*>(initial);`) and
          # accessed via `*deref` so that an inner lambda can capture
          # the cell pointer by value and outlive the enclosing stack
          # frame — fixes the dangling-by-reference closure bug.
          # Pushed/restored at each method/block/lambda body emission
          # via with_captured_locals.
          attr_accessor :captured_locals
          # Interned integer literals — every unique IntegerLiteral
          # value seen during emission becomes one shared static
          # Integer instance, referenced by address. Without interning,
          # the wq parser stub emits `(new Integer(805LL))` 6K+ times
          # (lexer state machine constants), drowning cc1plus.
          attr_reader :int_literals
          # Monotonic counter for unique helper-variable names —
          # MultipleAssignment uses this to avoid name collisions
          # between multiple MASS statements in the same scope.
          attr_accessor :tmp_counter
          # Big Integer-only Arrays seen during static-state capture
          # (lexer tables in particular — single 700KB+ lines of
          # `(&_f_i_X), ...` brace-init were the C++ compile-time
          # bottleneck). Emitted as raw `int64_t[]` arrays + a runtime
          # build call; cc1plus parses them as cheap static data.
          attr_reader :raw_int_arrays
          # Block-lambda context flag. Set true while emitting the body
          # of a Proc lambda from from_block_as_proc, so deeply-nested
          # expression-position emitters (from_if_as_lambda, from_case,
          # from_rescue) know to emit Break/Return as throws rather than
          # C++ break/return. Push/pop via with_in_block.
          attr_accessor :in_block
          # Tracks whether any `throw ReturnException{val, __frame_id__}`
          # was emitted during the current body rendering. Set by the
          # Return-as-throw emit site in expr_emitter.rb. Wrapped by
          # with_frame_id_tracking { ... } at the body-render boundary
          # in the 4 string-form override paths + the streaming method/
          # lambda body emit. Read post-hoc to decide whether the body
          # needs `next_frame_id()` + try/catch (ReturnException) at all.
          # Exact (no false positives) — strictly more precise than the
          # AST-walk body_needs_frame? predicate.
          attr_accessor :frame_id_used
          # Set true while emitting the body of an NA-with-block slot.
          # NA-with-block declares `Proc* block = nullptr`; bodies use
          # `_block != nullptr` for block_given?. Universal-slot bodies
          # use `_block != nil_instance()` (Phase-1 invariant: block
          # is BO* and never C++ nullptr). The block_given?
          # lowering in from_method_call switches on this flag.
          attr_accessor :block_is_nullable
          # Class variables seen during emission. Mapped: host-class flat
          # name (e.g. `:Frozone_Vm_ObjectObject`) → set of cvar names
          # (without the `@@` prefix). Each entry becomes a top-level
          # `static BO* cv_<flat>__<name> = nil_instance();`
          # in the post-class out-of-line section.
          attr_reader :class_vars

          # The load-phase Snapshot graph serializer. Set by the emitter
          # after discovery; when present, emit_vm_value routes slottable
          # objects (String/Array/Hash/ObjectObject) to their canonical
          # snapshot accessor instead of constructing them inline.
          attr_accessor :snapshot

          def initialize(user_classes:, user_constants:)
            @user_classes = user_classes
            @user_constants = user_constants
            @method_scope = []
            @super_context = nil
            @int_literals = {}
            seed_small_int_literals
            @raw_int_arrays = []
            @tmp_counter = 0
            @in_block = false
            @frame_id_used = false
            @block_is_nullable = false
            @cst_lift_cache = nil
            @captured_locals = Set.new
            @class_vars = Hash.new { |h, k| h[k] = Set.new }
          end

          # Run yield with @captured_locals = previous ∪ new_captures,
          # then restore. Each method/block/lambda body emission wraps
          # itself in this so its own captured locals (locals referenced
          # by inner blocks) are accessed via `*deref` while the body
          # is being emitted.
          def with_captured_locals(new_captures)
            prev = @captured_locals
            @captured_locals = prev | new_captures
            yield
          ensure
            @captured_locals = prev
          end

          def captured?(name) = @captured_locals.include?(name.to_s)

          # Flat C++ names of classes with no subclasses (Vm::ClassObject
          # leaves → "Frozone_Vm_X"-style strings). Cached. Used by the
          # is_a?(LeafKlass) typeid optimisation in from_method_call —
          # typeid match is sufficient for leaves since they have no
          # descendants by definition. Lazy because emit may not have a
          # leaf-classes computation yet at Cpp init.
          def cpp_leaf_names
            @cpp_leaf_names ||=
              if emit && emit.respond_to?(:compute_leaf_classes, true)
                # compute_leaf_classes is private on Emitter — bypass via send.
                emit.send(:compute_leaf_classes).map { |c| c.full_name.to_s.gsub("::", "_") }.to_set
              else
                Set.new
              end
          end

          # Class-variable reference: `@@foo` becomes a top-level static
          # `cv_<HostFlat>__<foo>`. HostFlat is the innermost real
          # (non-eigen, non-Object) class lexically containing the
          # def-site. Lexical scoping covers the common case (@@x
          # written in `class Foo` body, read in `Foo` instance methods);
          # subclass walks aren't modelled — Ruby would inherit storage
          # via the ancestor chain, but Frozone's own usage is single-
          # class, so we don't need that yet.
          def class_var_ref(name)
            host = host_class_for_class_var
            raise EmissionError, "@@#{name}: no enclosing class for class variable" unless host
            cvar = name.to_s.delete_prefix('@@').delete_prefix('@')
            @class_vars[host] << cvar
            "cv_#{host}__#{cvar}"
          end

          # Innermost class scope that owns class-variable storage —
          # walks @method_scope from inner→outer, skipping eigenclasses
          # and Object (top-level), and returns the flat C++ name of
          # the first concrete class.
          def host_class_for_class_var
            (@method_scope || []).reverse.each do |s|
              next unless s.is_a?(Vm::ModuleObject)
              next if s.respond_to?(:is_singleton_class) && s.is_singleton_class
              fname = s.full_name.to_s rescue nil
              next if fname.nil? || fname.empty? || fname == "Object"
              return fname.gsub("::", "_")
            end
            nil
          end

          # Run yield with `names` removed from @captured_locals (shadowing).
          # Used when an inner construct (for-loop expansion, block param)
          # introduces a fresh local that shadows an outer captured one
          # of the same name — the new local should be a bare stack
          # variable, not a heap cell.
          def with_shadowed_locals(names)
            prev = @captured_locals
            @captured_locals = prev - Set.new(names.map(&:to_s))
            yield
          ensure
            @captured_locals = prev
          end

          def next_tmp_id = (@tmp_counter += 1)

          # Body-render boundary: reset frame_id_used, yield, return
          # whether the body emitted at least one Return-as-throw site.
          # Restores prior value so nested method emissions stay isolated
          # (e.g. a Sequence containing a nested Ast::MethodDef).
          def with_frame_id_tracking
            saved = @frame_id_used
            @frame_id_used = false
            begin
              yield
              result = @frame_id_used
            ensure
              @frame_id_used = saved
            end
            result
          end

          def with_in_block
            saved = @in_block
            @in_block = true
            yield
          ensure
            @in_block = saved
          end

          # Top-level dispatch — turns an AST node into a cpp expression
          # string. Pure: no side effects. Recursive into sub-expressions.
          def from_expr(node, locals)
            raise EmissionError, "from_expr: nil node — caller passed missing AST" if node.nil?
            # Caller-self transport lift cache: from_method_call pre-renders
            # non-trivial recv/arg/kwarg sub-expressions into temporaries
            # before emitting `g_caller_self = X` so the temporaries
            # evaluate BEFORE the set (preventing the body-entry clear on
            # nested call bodies from clobbering it). Sub-renders during
            # the outer call's expression building look up here first to
            # pick up the tmp name. See from_method_call below.
            if @cst_lift_cache && (tmp = @cst_lift_cache[node.object_id])
              return tmp
            end
            case node
            when Ast::IntegerLiteral then intern_int(node.value.raw)
            when Ast::FloatLiteral   then "(new Float(#{node.value}))"
            when Ast::NilLiteral     then "nil_instance()"
            when Ast::TrueLiteral    then "true_instance()"
            when Ast::FalseLiteral   then "false_instance()"
            when Ast::SelfLiteral    then "this"
            when Ast::SymbolLiteral  then from_symbol_literal(node)
            when Ast::StringLiteral  then from_string_literal(node)
            when Ast::InterpolatedString then from_interpolated_string(node, locals)
            when Ast::ArrayLiteral   then from_array_literal(node, locals)
            when Ast::HashLiteral    then from_hash_literal(node, locals)
            when Ast::RangeLiteral   then from_range_literal(node, locals)
            when Ast::RegexpLiteral  then from_regexp_literal(node)
            when Ast::InterpolatedRegexpLiteral then from_interpolated_regexp_literal(node, locals)
            when Ast::LocalVariableRead then from_local_variable_read(node)
            when Ast::ConstantRead then from_constant_read(node)
            when Ast::ConstantPath then from_constant_path(node)
            when Ast::ConstantWrite then from_constant_write(node, locals)
            when Ast::ConstantPathWrite then from_constant_path_write(node, locals)
            when Ast::InstanceVariableRead then "this->iv_#{node.name.to_s.delete_prefix('@')}"
            when Ast::InstanceVariableWrite
              rhs = from_expr(node.value_node, locals)
              "(this->iv_#{node.name.to_s.delete_prefix('@')} = #{rhs})"
            when Ast::ClassVariableRead  then class_var_ref(node.name)
            when Ast::ClassVariableWrite then "(#{class_var_ref(node.name)} = #{from_expr(node.value_node, locals)})"
            when Ast::LocalVariableWrite
              rhs = from_expr(node.value_node, locals)
              if locals.include?(node.name.to_s)
                cpp = MethodEmitter.local_cpp_name(node.name)
                # Captured locals are heap cells (BO**) — write
                # via *deref so inner lambdas that captured the cell
                # pointer see the same heap memory.
                captured?(node.name) ? "(*#{cpp} = #{rhs})" : "(#{cpp} = #{rhs})"
              else
                # Local-decl in expr position needs scope hoisting
                # (declare in outer scope, assign here). Not implemented.
                raise EmissionError,
                  "LocalVariableWrite in expression position requires scope-hoisting (var: #{node.name}) — not implemented"
              end
            when Ast::MethodCall then from_method_call(node, locals)
            when Ast::AttributeWrite then from_attribute_write(node, locals)
            when Ast::IndexOperatorWrite then from_index_op_write(node, locals)
            when Ast::IndexOrWrite then from_index_or_write(node, locals)
            when Ast::IndexAndWrite then from_index_and_write(node, locals)
            when Ast::CallOrWrite then from_call_or_write(node, locals)
            when Ast::CallAndWrite then from_call_and_write(node, locals)
            when Ast::CallOperatorWrite then from_call_operator_write(node, locals)
            when Ast::And then from_and(node, locals)
            when Ast::Or then from_or(node, locals)
            when Ast::If then from_if(node, locals)
            when Ast::Case then from_case(node, locals)
            when Ast::Yield then from_yield(node, locals)
            when Ast::Lambda then from_lambda(node, locals)
            when Ast::IntrinsicCall then from_intrinsic_call(node, locals)
            when Ast::Rescue then from_rescue(node, locals)
            when Ast::Sequence
              # `(a)` and `(a, b, c)` lower to a comma-operator —
              # value is the last subexpression. But Sequence also
              # carries `begin..end` statement bodies whose elements
              # may include non-expression forms (`while`, `case`-as-
              # statement, …). In that case the comma-operator path
              # explodes because from_expr can't render them. Wrap in
              # an IIFE that runs the statements via write_body.
              if node.nodes.all? { |n| Cpp.expression_node?(n) }
                "(#{node.nodes.map { |n| from_expr(n, locals) }.join(", ")})"
              else
                "#{body_as_lambda(node, locals, last_is_return: true)}()"
              end
            when Ast::GlobalVariableRead then from_global_variable_read(node)
            when Ast::GlobalVariableWrite then from_global_variable_write(node, locals)
            when Ast::Super then from_super(node, locals)
            when Ast::DefinedExpr then from_defined_expr(node, locals)
            else
              raise EmissionError, "from_expr: unhandled AST node #{node.class.name}"
            end
          end

          # Trivial-for-caller-self-transport predicate. An AST node is
          # trivial here iff its rendered C++ expression evaluates to a
          # value without invoking any Ruby method body. Every body emits
          # an unconditional `g_caller_self = nullptr;` entry clear, so
          # any non-trivial sub-expression evaluated between the outer
          # call's `g_caller_self = X` set and its actual dispatch would
          # silently clobber the set — a visibility-bypass bug surfaced
          # by bench/stubs/visibility_arg_clobber_test.rb.
          #
          # Trivial:
          #   - Variable reads (local, ivar, cvar, gvar): direct loads
          #   - Literal values (Int/Float/Symbol/String/Nil/True/False)
          #   - self: just `this`
          #   - ConstantRead / ConstantPath: lower to `(&Foo_CLASS)` or
          #     `k_Foo()` — both are address-of-static / free-function
          #     accessor, NOT method-body dispatch.
          #
          # Non-trivial: everything else (MethodCall, And/Or, If/Case/Begin
          # as expression, ArrayLiteral, HashLiteral, InterpolatedString,
          # RangeLiteral, Yield, operator nodes, …).
          def self.trivial_for_caller_self_transport?(node)
            case node
            when Ast::LocalVariableRead, Ast::InstanceVariableRead,
                 Ast::ClassVariableRead, Ast::GlobalVariableRead,
                 Ast::SelfLiteral,
                 Ast::IntegerLiteral, Ast::FloatLiteral, Ast::SymbolLiteral,
                 Ast::NilLiteral, Ast::TrueLiteral, Ast::FalseLiteral,
                 Ast::StringLiteral,
                 Ast::ConstantRead, Ast::ConstantPath
              true
            else
              false
            end
          end

          # Universal call protocol: every Ruby method call is
          #   recv->m_X(args_array, kwargs_hash_or_nullptr, block_or_nullptr)
          # where args_array is `(new Array({a, b, ...}))`. The called
          # method's body unpacks args to its declared params.
          # Specializations like `m_X_1(arg)` are an optimisation layer
          # we may add later (per call-site mangling); for now everything
          # is generic.
          def from_method_call(node, locals)
            recv = node.receiver_node
            name = node.name
            arg_nodes = node.arg_nodes || []
            kw_nodes  = node.kw_arg_nodes  || []
            kw_splats = node.kw_splat_nodes || []

            # Stash for from_expr_recv below. Cleared at top of method
            # so a nested call can install its own pattern; we restore
            # afterwards to support call-in-arg nesting.
            prev_vis_name = @vis_check_name
            @vis_check_name = name
            begin
              pattern = emit&.visibility_survey&.per_name&.[](name)
              # When the callee name is P4 (mixed-vis) — the only case
              # where the outer `g_caller_self = X` set matters — and any
              # recv/arg/kwarg sub-expression is non-trivial, hoist those
              # sub-expressions into temporaries BEFORE the set. P1 sites
              # skip the wrap entirely (no transport needed). P2/P3 sites
              # decide visibility statically at the call site — no body
              # prologue reads g_caller_self.
              if pattern && pattern != :p1 && needs_caller_self_lift?(recv, arg_nodes, kw_nodes, kw_splats)
                emit_call_with_caller_self_lift(node, recv, name, arg_nodes, kw_nodes, kw_splats, locals, pattern)
              else
                call_expr = from_method_call_inner(node, recv, name, arg_nodes, locals)
                wrap_p4_caller_self_set(call_expr, recv_node: recv)
              end
            ensure
              @vis_check_name = prev_vis_name
            end
          end

          # SplatArg / kw-splat wrappers don't render via from_expr directly —
          # from_method_call_inner's args-array builder calls
          # `from_expr(a.value_node, …)` and wraps it with splat_to_array.
          # So for triviality, peek through the wrapper to the inner value.
          def self.unwrap_for_lift(node)
            return nil if node.nil?
            return node.value_node if node.is_a?(Ast::SplatArg)
            node
          end

          def needs_caller_self_lift?(recv, arg_nodes, kw_nodes, kw_splats)
            return true if recv && !Cpp.trivial_for_caller_self_transport?(recv)
            return true if arg_nodes.any? { |a| sub = Cpp.unwrap_for_lift(a); sub && !Cpp.trivial_for_caller_self_transport?(sub) }
            return true if kw_nodes.any? { |(_, v)| !Cpp.trivial_for_caller_self_transport?(v) }
            return true if kw_splats.any? { |n| sub = Cpp.unwrap_for_lift(n); sub && !Cpp.trivial_for_caller_self_transport?(sub) }
            false
          end

          # Render the outer call with non-trivial sub-expressions hoisted
          # into temporaries, then `g_caller_self = X`, then dispatch.
          # IIFE form so the whole thing is a single expression. Cache maps
          # node.object_id → tmp name; from_expr picks tmps up transparently.
          def emit_call_with_caller_self_lift(node, recv, name, arg_nodes, kw_nodes, kw_splats, locals, _pattern)
            saved_cache = @cst_lift_cache
            @cst_lift_cache = saved_cache ? saved_cache.dup : {}
            tmp_decls = []
            lift = lambda do |sub|
              return if sub.nil?
              return if Cpp.trivial_for_caller_self_transport?(sub)
              return if @cst_lift_cache.key?(sub.object_id)
              # Render the sub WITHOUT the lift cache visible to itself
              # (saved_cache scope), so nested method calls within the
              # sub get their own lift treatment via from_method_call.
              prev_cache = @cst_lift_cache
              @cst_lift_cache = saved_cache
              begin
                rendered = from_expr(sub, locals)
              ensure
                @cst_lift_cache = prev_cache
              end
              tmp = "_csat_#{next_tmp_id}"
              tmp_decls << "BO* #{tmp} = #{rendered};"
              @cst_lift_cache[sub.object_id] = tmp
            end
            lift.call(recv) if recv
            arg_nodes.each      { |a| lift.call(Cpp.unwrap_for_lift(a)) }
            kw_nodes.each       { |(_, v)| lift.call(v) }
            kw_splats.each      { |n| lift.call(Cpp.unwrap_for_lift(n)) }
            # Re-render the call expression using the cached tmps. Any
            # remaining sub-expression renders are trivial (literals / loads),
            # so they don't re-clobber.
            inner_call = from_method_call_inner(node, recv, name, arg_nodes, locals)
            cs_value = (recv.nil? || recv.is_a?(Ast::SelfLiteral)) ? 'nullptr' : 'this'
            decls = tmp_decls.join(' ')
            result = Cpp.block_expr(
              [decls, "g_caller_self = #{cs_value};"],
              inner_call
            )
            @cst_lift_cache = saved_cache
            result
          end

          # Stage 3 + Stage 4: every call site for a non-public name
          # transports the caller's `self` via the thread_local
          # `g_caller_self` so the callee body's prologue (Stage 3 added
          # by emit_visibility_prologue) can apply the runtime check.
          #
          #   nullptr  → privileged form (implicit recv, explicit-self).
          #              Allows entry to private / protected bodies.
          #   `this`   → explicit-other dispatch. Private body raises;
          #              protected body applies kind_of? against `this`.
          #
          # P1 (all-public) names skip this — no body prologue cares.
          # public_send dispatch sets PUBLIC_SEND_SENTINEL at the
          # intrinsic level (cpp/runtime/intrinsics/object_intrinsics.hpp).
          def wrap_p4_caller_self_set(call_expr, recv_node:)
            pattern = emit&.visibility_survey&.per_name&.[](@vis_check_name)
            return call_expr if pattern.nil? || pattern == :p1
            cs_value = (recv_node.nil? || recv_node.is_a?(Ast::SelfLiteral)) ? 'nullptr' : 'this'
            "(g_caller_self = #{cs_value}, #{call_expr})"
          end

          # Receiver-fetch hook: for explicit-other calls to P2 (all-
          # private) or P3 (all-protected) method names, wrap the
          # receiver expression with the appropriate runtime check.
          # Used by from_method_call_inner; pure pass-through when no
          # check is needed (implicit recv, explicit self, P1/P4 names,
          # or no survey available).
          def recv_with_visibility_check(recv_node, locals)
            recv_str = from_expr(recv_node, locals)
            # `self.foo` syntax is the only relaxation in 4.x: explicit
            # receiver as the literal `self` token is allowed for
            # non-public targets. Every other explicit-recv form is
            # checked, even ones that happen to evaluate to self at
            # runtime (MRI's check is syntactic, not value-equality).
            return recv_str if recv_node.is_a?(Ast::SelfLiteral)
            pattern = emit&.visibility_survey&.per_name&.[](@vis_check_name)
            case pattern
            when :p2
              # All-private: any non-`self`-literal explicit receiver
              # raises NoMethodError unconditionally — no runtime test
              # needed. The IIFE evaluates recv (preserving side
              # effects, matching MRI's "evaluate receiver first then
              # raise" order) and raises before the call would dispatch.
              Cpp.throw_expr([
                "auto* _r = #{recv_str};",
                "raise_private_call(_r, #{cpp_string_literal(@vis_check_name.to_s)});"
              ])
            when :p3
              # All-protected: caller's self must kind_of? receiver's class.
              Cpp.block_expr(
                ["auto* _r = #{recv_str};",
                 "if (!truthy(this->mm_kind_of_q(univ, new Array({_r->m_class(univ)})))) raise_protected_call(_r, #{cpp_string_literal(@vis_check_name.to_s)});"],
                "_r"
              )
            else
              recv_str
            end
          end

          # Original from_method_call body, lifted into a helper so the
          # outer wrapper can install @vis_check_name. The body delegates
          # receiver fetches to recv_with_visibility_check when wrapping
          # is potentially needed; bare from_expr otherwise (e.g. for
          # `recv.is_a?(Klass)` short-circuit which is just a typeid test).
          def from_method_call_inner(node, recv, name, arg_nodes, locals)

            # `raise` is a statement-like keyword in Ruby that we lower
            # to a C++ `throw` wrapped in a lambda (so it composes in
            # expression position too).
            return from_raise(arg_nodes, locals) if !recv && name == :raise

            # `block_given?` checks the ENCLOSING method's block — the
            # `_block` local that unpack_params binds. Going through the
            # universal vtable would receive the block passed to the
            # block_given? call itself, not the enclosing method's,
            # which is wrong. Special-case to a direct check.
            return "boxed_bool(_block != #{@block_is_nullable ? 'nullptr' : 'nil_instance()'})" if !recv && name == :block_given?

            # `binding.local_variable_get(SYM)` — Frozone-Ruby uses this
            # to access locals whose names collide with Ruby keywords
            # (`in:`, `class:`, etc.) — the kwarg value is unreachable
            # by bare identifier so `binding.local_variable_get(:in)` is
            # MRI's canonical escape hatch. Lower directly to a read of
            # the enclosing method's C++ local, same as a LocalVariableRead
            # would. Works uniformly for positional/kwarg/optional locals
            # regardless of NA / kw_unset eligibility — the prologue has
            # always materialised an `l_<name>` local by the time the body
            # runs. The Binding object never has to exist; kernel_binding
            # stays abort-stubbed for dynamic-name / arbitrary use.
            # If `:name` isn't a real local in the enclosing method the
            # emitted `l_<name>` is a C++ undefined-name error — loud at
            # build time, which is what we want for typos.
            if name == :local_variable_get && arg_nodes.length == 1 &&
               arg_nodes[0].is_a?(Ast::SymbolLiteral) &&
               recv.is_a?(Ast::MethodCall) && recv.receiver_node.nil? &&
               recv.name == :binding && (recv.arg_nodes || []).empty?
              sym = arg_nodes[0].value
              cpp = MethodEmitter.local_cpp_name(sym)
              return captured?(sym) ? "(*#{cpp})" : cpp
            end

            # `recv.is_a?(LeafClass)` / kind_of? / instance_of? when the
            # literal arg resolves to a C++-leaf class — emit a typeid
            # match instead of going through mm_is_a_q's LUT. For leaves
            # typeid identity equals "is_a"-with-no-subclasses by
            # definition. instance_of? is exact-class semantics — also
            # equivalent. The typeid_eq_q<T> template member on
            # BasicObject defers T's completeness to the call site, where
            # the per-TU pruner has already #include'd class/T.hpp via
            # host_class_refs (ConstantRead reference detection).
            if recv && %i[is_a? kind_of? instance_of?].include?(name) &&
               arg_nodes.length == 1 &&
               (arg_nodes[0].is_a?(Ast::ConstantRead) || arg_nodes[0].is_a?(Ast::ConstantPath))
              knode = arg_nodes[0]
              parts = knode.is_a?(Ast::ConstantRead) ? [knode.name.to_s] : collect_path(knode)
              flat = resolve_constant(parts)
              if flat && cpp_leaf_names.include?(flat.to_s)
                return "boxed_bool(#{from_expr(recv, locals)}->typeid_eq_q<#{flat}>())"
              elsif flat && %i[is_a? kind_of?].include?(name)
                # Non-leaf is_a?/kind_of? — direct LUT lookup via
                # mm_is_a_q_direct skips the universal-protocol Array
                # allocation. instance_of? falls through to universal
                # dispatch (mm_instance_of_q does exact-class match,
                # not LUT lookup).
                return "boxed_bool(#{from_expr(recv, locals)}->mm_is_a_q_direct(&#{flat}_CLASS))"
              end
            end

            # `.new` has no special case: `Foo.new(args)` dispatches via
            # the universal protocol on the eigenclass singleton — i.e.
            # `(&Foo_CLASS)->m_new(args, kwargs, block)`. The eigenclass
            # auto-emits an m_new override that does
            # `Foo* obj = new Foo(); obj->m_initialize(args, ...); return obj;`.

            # Block-bearing call site: wrap the block as a Proc and pass
            # as the third call-protocol arg. (`recv.times { ... }` in
            # statement context is special-cased to a C++ for-loop by
            # ExprEmitter#write_stmt BEFORE from_expr is reached; here
            # we always preserve the block — dropping it in expression
            # context would silently produce `m_times(nullptr)` and
            # never execute the body. Soundness > slight Proc-alloc cost.)
            has_block = !!node.block_node
            block_arg = has_block ? from_block_as_proc(node.block_node, locals) : "nil_instance()"

            # Natural-arity dispatch. If the target name is eligible
            # AND the call shape is compatible (positional only, no
            # block, no kwargs, no splat, arity matches), emit a
            # direct natural-arity virtual call that skips the args-
            # Array allocation. Incompatible-shape calls (splat /
            # kwargs) of eligible names go through the per-name
            # trampoline free function which takes universal-shape
            # args and forwards to the natural-arity slot.
            na_sig = emit&.natural_arity_names&.dig(name)
            # Compatibility for natural-arity dispatch: positional
            # arg count matches sig.arity_req, no splat / kw-splat /
            # block. If the sig has required-kw names, the call site
            # must also supply EXACTLY that set of literal kw_arg
            # names (no extras, no missing). Reorder the call's kw
            # args to match the sig's declaration (sorted) order.
            na_kw_csv = nil
            kw_compat = if na_sig
              call_kw_names = (node.kw_arg_nodes || []).map do |k, _|
                k.respond_to?(:value) ? k.value.to_sym : nil
              end
              if na_sig.required_kw_names.empty?
                (node.kw_arg_nodes || []).empty? && (node.kw_splat_nodes || []).empty?
              elsif (node.kw_splat_nodes || []).any?
                false
              elsif call_kw_names.sort == na_sig.required_kw_names
                kw_map = (node.kw_arg_nodes || []).to_h { |k, v| [k.value.to_sym, v] }
                na_kw_csv = na_sig.required_kw_names.map { |kn| from_expr(kw_map[kn], locals) }
                true
              else
                false
              end
            end
            # has_block at call site is serviced by the NA slot iff
            # the sig is na_with_block. Block-less calls to a
            # has_block slot rely on the slot's default Proc* arg.
            na_compatible = na_sig &&
                            arg_nodes.length == na_sig.arity_req &&
                            arg_nodes.none? { |a| a.is_a?(Ast::SplatArg) } &&
                            (!has_block || na_sig.has_block) &&
                            kw_compat

            if na_compatible
              pos_csv = arg_nodes.map { |a| from_expr(a, locals) }
              all_parts = pos_csv + (na_kw_csv || [])
              if na_sig.has_block
                # NA-with-block slot expects `Proc* block` — convert
                # the universal-style block_arg at the seam: drop
                # nil_instance() to nullptr (the slot's "absent block"
                # sentinel); pass real blocks through unchanged (they're
                # already Proc-typed via from_block_as_proc).
                all_parts << (has_block ? block_arg : "nullptr")
              end
              all_csv = all_parts.join(', ')
              call_expr =
                if recv && node.safe_nav
                  recv_str = from_expr(recv, locals)
                  Cpp.block_expr(
                    ["auto* _r = #{recv_str};"],
                    "(_r == nil_instance()) ? nil_instance() : _r->#{Cpp.method_name(name)}(#{all_csv})"
                  )
                elsif recv
                  "#{recv_with_visibility_check(recv, locals)}->#{Cpp.method_name(name)}(#{all_csv})"
                else
                  "this->#{Cpp.method_name(name)}(#{all_csv})"
                end
              # NA-with-block path: also try stack-alloc when target
              # is non-escaping. No break-catch wrap here — yield-driven
              # NA-with-block bodies don't currently throw BreakException
              # at the iterator boundary; if they ever do (#168 follow-up),
              # add wrap_break_catch around call_expr first.
              if has_block
                return maybe_stack_alloc_block(call_expr, block_arg, name) || call_expr
              end
              return call_expr
            end

            # Multi-arity dispatch — same shape as natural-arity but
            # picks the overload by argument count. Compatible call:
            # static positional arity in family, no kwargs/splat/block.
            mu_family = emit&.multi_arity_table&.dig(name)
            mu_compatible = mu_family &&
                            arg_nodes.none? { |a| a.is_a?(Ast::SplatArg) } &&
                            (node.kw_arg_nodes || []).empty? &&
                            (node.kw_splat_nodes || []).empty? &&
                            !has_block &&
                            mu_family.arities.include?(arg_nodes.length)
            if mu_compatible
              pos_csv = arg_nodes.map { |a| from_expr(a, locals) }.join(', ')
              if recv && node.safe_nav
                recv_str = from_expr(recv, locals)
                return Cpp.block_expr(
                  ["auto* _r = #{recv_str};"],
                  "(_r == nil_instance()) ? nil_instance() : _r->#{Cpp.method_name(name)}(#{pos_csv})"
                )
              elsif recv
                return "#{recv_with_visibility_check(recv, locals)}->#{Cpp.method_name(name)}(#{pos_csv})"
              else
                return "this->#{Cpp.method_name(name)}(#{pos_csv})"
              end
            end

            # Kw-unset dispatch — kw-bearing names whose call shape we
            # can resolve statically: positional count in [arity_req,
            # arity_req+opt], no splat, no kw_splat, no block. Required
            # kws must be supplied by the caller; optional kws are
            # filled with UNSET when not supplied. Slot order: required
            # pos → opt pos (UNSET-able) → all kws sorted alphabetical.
            kw_sig = emit&.kw_unset_table&.dig(name)
            ku_compatible = kw_sig &&
                            arg_nodes.none? { |a| a.is_a?(Ast::SplatArg) } &&
                            (node.kw_splat_nodes || []).empty? &&
                            !has_block &&
                            arg_nodes.length >= kw_sig.arity_req &&
                            arg_nodes.length <= kw_sig.arity_req + kw_sig.opt
            kw_call_csv = nil
            if ku_compatible
              call_kw_map = (node.kw_arg_nodes || []).each_with_object({}) do |(k, v), h|
                kn = k.respond_to?(:value) ? k.value.to_sym : nil
                h[kn] = v if kn
              end
              # Every required kw must be supplied; extras (not in
              # all_kw_names) disqualify the static lowering.
              required_present = kw_sig.required_kw_names.all? { |kn| call_kw_map.key?(kn) }
              extras = call_kw_map.keys - kw_sig.all_kw_names
              if !(required_present && extras.empty?)
                ku_compatible = false
              end
            end
            if ku_compatible
              # Pre-evaluate every arg expression in Ruby source order
              # (positionals left-to-right, then kws in source order).
              # C++ argument evaluation order is unspecified, so building
              # the call directly would risk reordering side effects.
              # IIFE with temp bindings gives MRI-matching semantics; the
              # compiler optimises away pure temps.
              pos_temps = arg_nodes.each_with_index.map do |a, i|
                ["_pos_#{i}", from_expr(a, locals)]
              end
              kw_source_temps = (node.kw_arg_nodes || []).map do |k, v|
                kn = k.value.to_sym
                ["_kw_#{kn}_v", from_expr(v, locals)]
              end
              decls = (pos_temps + kw_source_temps).map { |n, e| "BO* #{n} = #{e};" }.join(' ')
              pos_refs = pos_temps.map(&:first)
              pos_pad_refs = Array.new(kw_sig.arity_req + kw_sig.opt - arg_nodes.length, "unset_instance()")
              kw_refs = kw_sig.all_kw_names.map do |kn|
                call_kw_map.key?(kn) ? "_kw_#{kn}_v" : "unset_instance()"
              end
              call_csv = (pos_refs + pos_pad_refs + kw_refs).join(', ')
              if recv && node.safe_nav
                recv_str = from_expr(recv, locals)  # safe_nav: visibility check deferred — would need to fold into the nil short-circuit IIFE
                return Cpp.staged_block_expr([
                  { stmts: ["auto* _r = #{recv_str};"],
                    early_return: { cond: "_r == nil_instance()", value: "nil_instance()" } },
                  { stmts: [decls],
                    value: "_r->#{Cpp.method_name(name)}(#{call_csv})" }
                ])
              elsif recv
                recv_str = recv_with_visibility_check(recv, locals)
                return Cpp.block_expr(
                  ["auto* _r = #{recv_str};", decls],
                  "_r->#{Cpp.method_name(name)}(#{call_csv})"
                )
              else
                return Cpp.block_expr(
                  [decls],
                  "this->#{Cpp.method_name(name)}(#{call_csv})"
                )
              end
            end

            args_array = build_args_array(arg_nodes, locals)
            kwargs_arg = build_kwargs_hash(node.kw_arg_nodes || [], node.kw_splat_nodes || [], locals)

            # Eligible name but incompatible call shape: dispatch via
            # the universal-sig overload on the receiver — its body is
            # the per-name trampoline that routes into the right
            # per-arity overload. No parallel TRAMPOLINE_VT.
            if (na_sig || mu_family || kw_sig) && recv
              if node.safe_nav
                recv_str = from_expr(recv, locals)  # safe_nav: visibility check deferred — would need to fold into the nil short-circuit IIFE
                tail = univ_call_explicit_tail(Cpp.method_name(name), args_array, kwargs_arg, block_arg)
                return Cpp.block_expr(
                  ["auto* _r = #{recv_str};"],
                  "(_r == nil_instance()) ? nil_instance() : _r#{tail}"
                )
              else
                return univ_call_explicit(recv_with_visibility_check(recv, locals), Cpp.method_name(name), args_array, kwargs_arg, block_arg)
              end
            elsif (na_sig || mu_family || kw_sig) && !recv
              return univ_call_explicit("this", Cpp.method_name(name), args_array, kwargs_arg, block_arg)
            end

            call_expr =
              if recv
                if node.safe_nav
                  # `recv&.foo(args)` — short-circuit to nil when recv
                  # is nil_instance(); MRI semantics short-circuit on
                  # nil only (NOT on false). Compute the receiver once
                  # via IIFE to avoid double-evaluation of side effects.
                  # safe_nav skips visibility check (Stage 2b).
                  recv_str = from_expr(recv, locals)
                  tail = univ_call_tail(Cpp.method_name(name), args_array, kwargs_arg, block_arg)
                  Cpp.block_expr(
                    ["auto* _r = #{recv_str};"],
                    "(_r == nil_instance()) ? nil_instance() : _r#{tail}"
                  )
                else
                  univ_call(recv_with_visibility_check(recv, locals), Cpp.method_name(name), args_array, kwargs_arg, block_arg)
                end
              elsif name == :puts
                # ruby_puts returns void; Ruby's puts returns nil — comma
                # operator gives the right type for expression contexts.
                # ruby_puts is a runtime free function (NOT a vtable
                # method) so it bypasses the universal call protocol.
                # Bare `puts` (no args) prints a newline — match
                # intrinsic_kernel_puts's empty-array branch.
                args = arg_nodes.map { |a| from_arg(a, locals) }
                if args.empty?
                  "(ruby_puts(static_cast<BO*>(nullptr)), nil_instance())"
                else
                  "(#{args.map { |a| "ruby_puts(#{a})" }.join(", ")}, nil_instance())"
                end
              else
                univ_call("this", Cpp.method_name(name), args_array, kwargs_arg, block_arg)
              end

            # `break v` inside the block becomes `throw BreakException{v}`
            # — caught here so the iterator's call expression evaluates
            # to v. Wrap only when a block was actually passed; non-block
            # calls can't break-out (no Proc → no BreakException).
            if has_block
              wrapped = wrap_break_catch(call_expr)
              return maybe_stack_alloc_block(wrapped, block_arg, name) || wrapped
            end
            call_expr
          end

          def wrap_break_catch(call_expr)
            Cpp.try_catch_expr(call_expr, "BreakException& e_", "e_.value")
          end

          # Stack-alloc the Proc instance when the call target is a known
          # non-escaping iterator. block_arg has the shape
          # `(new ProcN([CAP](ARGS)->BO*{BODY}))` — strip the
          # `new`+`)` to get the ctor body, declare a stack ProcN inside
          # a self-invoking lambda whose frame outlives the call,
          # substitute the heap form with a pointer-to-stack ref.
          # Returns nil (caller falls back to the original heap form) on
          # any mismatch — safety first.
          #
          # Non-escape eligibility comes from the closed-world escape
          # analysis in MethodShapeSurvey (per-def block-param tracking
          # + recursive forwards fixed-point). Stored on the emitter as
          # `non_escaping_block_names`.

          def maybe_stack_alloc_block(call_expr, block_arg, name)
            return nil unless ENV['FROZONE_STACK_BLOCKS'] == '1'
            return nil unless emit&.non_escaping_block_names&.include?(name)
            return nil unless block_arg.is_a?(String) && block_arg.start_with?('(new Proc') && block_arg.end_with?('))')
            m = /\A\(new (Proc\d?)\(/.match(block_arg)
            return nil unless m
            proc_cls = m[1]
            ctor = block_arg[m[0].length...-2]
            # Replace the heap form with &__blk__. block_arg strings are
            # long and unlikely to repeat — but verify uniqueness; ambiguous
            # match means we can't safely rewrite.
            return nil unless call_expr.scan(block_arg).length == 1
            ref_form = call_expr.sub(block_arg, '&__blk__')
            Cpp.block_expr(
              ["#{proc_cls} __blk__(#{ctor});"],
              ref_form
            )
          end

          # Build the kwargs Hash for a call. Empty kw list AND no
          # **splat → EMPTY_KWARGS singleton (no allocation). Literal
          # kw pairs → `(new Hash({{intern("k"), v}, ...}))`. **splat
          # forwards the source Hash directly when it's the only kw
          # input; mixed literal+splat builds a fresh Hash and merges.
          def build_kwargs_hash(kw_arg_nodes, kw_splat_nodes, locals)
            return "(&EMPTY_KWARGS)" if kw_arg_nodes.empty? && kw_splat_nodes.empty?
            entries = kw_arg_nodes.map do |key_node, value_node|
              key_name = key_node.is_a?(Ast::SymbolLiteral) ? key_node.value.to_s : nil
              raise EmissionError, "non-symbol kw key not supported" unless key_name
              "{intern(#{cpp_string_literal(key_name)}), static_cast<BO*>(#{from_expr(value_node, locals)})}"
            end
            # Pure single-splat (`**h` with no literal pairs) — forward
            # the source Hash directly, avoiding the alloc + copy.
            if kw_arg_nodes.empty? && kw_splat_nodes.length == 1
              return "static_cast<Hash*>(#{from_expr(kw_splat_nodes[0], locals)})"
            end
            # Mixed or multi: build a fresh Hash, populate with literal
            # pairs, then copy each splat source's entries on top.
            splat_pushes = kw_splat_nodes.map do |s|
              "_h->copy_kvps_from(*static_cast<Hash*>(#{from_expr(s, locals)}));"
            end
            Cpp.block_expr(
              ["Hash* _h = new Hash({#{entries.join(', ')}});"] + splat_pushes,
              "_h",
              type: 'Hash*'
            )
          end

          # Compose the trailing `(args, kwargs, block)` of a method
          # call. Drops trailing defaults: args=&EMPTY_ARGS,
          # kwargs=&EMPTY_KWARGS, block=nil_instance(). So
          # `(EMPTY_ARGS, EMPTY_KWARGS, nil)` collapses to `()`,
          # `(args, EMPTY_KWARGS, nil)` to `(args)`, etc.
          DEFAULT_TRAILING_PARTS = ["(&EMPTY_ARGS)", "(&EMPTY_KWARGS)", "nil_instance()"].freeze
          def call_tail(args_str, kwargs_str, block_str)
            parts = [args_str, kwargs_str, block_str]
            parts.pop while parts.size > 0 && DEFAULT_TRAILING_PARTS.include?(parts.last)
            # UnivTag fence: every universal-vtable call gets `univ` as
            # first arg. Trailing positional defaults still drop.
            "(univ#{parts.empty? ? '' : ', ' + parts.join(', ')})"
          end

          # Compose the full universal-protocol call expression.
          # Single source of truth for the call shape — every emit site
          # that issues a universal-vtable dispatch should route through
          # here so future call-shape changes (e.g. UnivTag fence) need
          # only one edit. `recv_expr` is the C++ receiver expression
          # (or "this", "_r", etc.); `method` is the cpp_name. Trailing
          # defaults are dropped via call_tail.
          def univ_call(recv_expr, method, args_str = "(&EMPTY_ARGS)", kwargs_str = "(&EMPTY_KWARGS)", block_str = "nil_instance()")
            "#{recv_expr}->#{method}#{call_tail(args_str, kwargs_str, block_str)}"
          end

          # Same as univ_call but for the (args, kwargs, block) trailing
          # portion only — used by sites that already have the
          # `recv->method` prefix constructed (e.g. the safe-nav IIFE).
          def univ_call_tail(method, args_str = "(&EMPTY_ARGS)", kwargs_str = "(&EMPTY_KWARGS)", block_str = "nil_instance()")
            "->#{method}#{call_tail(args_str, kwargs_str, block_str)}"
          end

          # Universal-call emit for sites that keep the explicit
          # (args, kwargs, block) shape regardless of default values —
          # used by NA-bearing trampoline dispatch where the universal-
          # sig overload exists alongside per-arity overloads. The
          # explicit form disambiguates against the per-arity overloads
          # and keeps the gen output stable.
          def univ_call_explicit(recv_expr, method, args_str, kwargs_str, block_str)
            "#{recv_expr}->#{method}(univ, #{args_str}, #{kwargs_str}, #{block_str})"
          end

          def univ_call_explicit_tail(method, args_str, kwargs_str, block_str)
            "->#{method}(univ, #{args_str}, #{kwargs_str}, #{block_str})"
          end

          # Build the args Array for a call. Cases:
          # - Empty: (&EMPTY_ARGS) — stable read-only singleton, no alloc
          # - All literal args: (new Array({a, b, ...}))
          # - Single splat: pass the splat's value directly (it's
          #   already an Array — no wrapping)
          # - Mixed splat+literal: defer (would need flattening logic).
          def build_args_array(arg_nodes, locals)
            return "(&EMPTY_ARGS)" if arg_nodes.empty?
            if arg_nodes.length == 1 && arg_nodes[0].is_a?(Ast::SplatArg)
              # `f(*x)` — pass x's elements as the call's args. Goes
              # through splat_to_array which handles non-Array x via
              # MRI's to_a protocol (e.g. AST::Node aliases to_a children).
              "splat_to_array(#{from_expr(arg_nodes[0].value_node, locals)})"
            elsif arg_nodes.any? { |a| a.is_a?(Ast::SplatArg) }
              # Mixed positional + splat: flatten into a fresh Array
              # via a lambda that pushes each piece. Splats append
              # all elements, positionals append singly.
              push_lines = arg_nodes.map do |a|
                if a.is_a?(Ast::SplatArg)
                  "for (auto* _e : splat_to_array(#{from_expr(a.value_node, locals)})->data) _r->data.push_back(_e);"
                else
                  "_r->data.push_back(#{from_expr(a, locals)});"
                end
              end
              Cpp.block_expr(
                ["Array* _r = new Array();"] + push_lines,
                "_r",
                type: 'Array*'
              )
            else
              args = arg_nodes.map { |a| from_expr(a, locals) }
              "(new Array({#{args.join(", ")}}))"
            end
          end

          # Single arg in a MethodCall.arg_nodes list. Splat-args
          # (`foo(*arr)`) emit the splat's value directly — the called
          # method's rest_param receives the Array as-is. No flattening
          # in our model: `foo(1, *arr, 5)` would pass them as 3
          # positional args, NOT as the Ruby-semantic flattened list
          # — defer the flattening case until needed.
          # C++ expression for one method-call argument. SplatArg in this
          # slot is a bug — splats need flattening into the args Array at
          # the call site (see build_args_array in from_method_call), not
          # silent unwrapping to the underlying value (which would treat
          # `*[1,2,3]` as `[1,2,3]` instead of three positional args).
          # Loud EmissionError so the unhandled site gets fixed instead of
          # silently emitting wrong code.
          def from_arg(node, locals)
            if node.is_a?(Ast::SplatArg)
              raise Cpp::EmissionError,
                    "SplatArg passed through from_arg — caller needs splat-aware path " \
                    "(method-call arg lists go via build_args_array; index/raise/IOW " \
                    "args don't accept splats today)"
            end
            from_expr(node, locals)
          end

          # IntrinsicCall lowering. `Intrinsics.foo(self, args...)`
          # bypasses the universal protocol and emits direct C++
          # specialised to the receiver type encoded in the intrinsic
          # name (`array_*` → cast to Array*, `integer__plus_` → cast to
          # Integer*, etc.). For closed-world AOT this is exactly the
          # specialisation we want — no vtable, no Array allocation
          # for args, no static_cast at runtime, just the underlying op.
          # Templates are explicit per-intrinsic (no name-based
          # heuristic — too many edge cases). Unknown intrinsic →
          # EmissionError → method skipped (graceful degradation).
          # Captured locals are stored as heap cells (`BO**`)
          # so a Proc that captures the cell pointer outlives the
          # enclosing stack frame. Reads dereference; non-captured
          # locals stay on the stack as bare `BO*`.
          def from_local_variable_read(node)
            cpp = MethodEmitter.local_cpp_name(node.name)
            captured?(node.name) ? "(*#{cpp})" : cpp
          end

          def from_intrinsic_call(node, locals)
            # `Intrinsics.foo(self, *args)` — splat at the intrinsic call
            # site is common in core/4.0/ wrappers like
            # `def count(*args) = Intrinsics.string_count_raw(self, *__str_args__(*args))`.
            # Lower the splat by passing the inner expression (which
            # yields an Array) directly. The C++ intrinsic must accept
            # Array* (or BO*) at that position — i.e. the
            # variadic Ruby signature becomes a single Array param in C++.
            args = node.param_nodes.map do |p|
              p.is_a?(Ast::SplatArg) ? from_expr(p.value_node, locals) : from_expr(p, locals)
            end
            IntrinsicLowering.lower(node.name, *args)
          end

          # `Ast::Yield` → call into the implicit `_block` Proc* that
          # MethodEmitter inserts when a body contains yield.
          #
          # Fast paths via arity-specialized Proc slots:
          # - yield (0 args, no kw)         → _block->call0()
          # - yield x (1 arg,  no kw)       → _block->call1(x)
          # - yield x, y (2 args, no kw)    → _block->call2(x, y)
          # When _block is a Proc1/Proc2/Proc0 (the matching specialized
          # subclass), the callN override skips the Array allocation
          # entirely. When _block is a generic Proc, base callN wraps
          # in an Array internally — same semantics as the old path.
          #
          # 3+ args or any kwargs → universal m_call(args, kwargs).
          def from_yield(node, locals)
            args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
            kw_arg_nodes = node.respond_to?(:kw_arg_nodes) ? (node.kw_arg_nodes || {}) : {}
            has_kw = !kw_arg_nodes.empty?
            unless has_kw
              return "_block->call0()" if args.empty?
              return "_block->call1(#{args[0]})" if args.length == 1
              return "_block->call2(#{args[0]}, #{args[1]})" if args.length == 2
            end
            args_expr = args.empty? ? "&EMPTY_ARGS" : "new Array({#{args.join(", ")}})"
            return "_block->m_call(univ, #{args_expr})" unless has_kw
            # Use Hash::put rather than raw data[k] = v — keeps insertion-
            # order vector + order_idx in sync. Direct data[] bypasses
            # those, and downstream **rest extraction (which iterates
            # over `data` for filter-by-name) may silently lose entries
            # because the Hash's internal invariants get out of sync.
            kw_pairs = kw_arg_nodes.map do |k_node, v_node|
              key_lit = k_node.respond_to?(:value) ? k_node.value.to_s.inspect : k_node.to_s.inspect
              "_kw->put(intern(#{key_lit}), #{from_expr(v_node, locals)});"
            end
            kw_expr = Cpp.block_expr(
              ["Hash* _kw = new Hash();"] + kw_pairs,
              "_kw",
              type: 'Hash*'
            )
            "_block->m_call(univ, #{args_expr}, #{kw_expr})"
          end

          # C++ argument-list string for a method-call lowering. NA-direct
          # form (positional args inline) when `name` has an NA slot whose
          # `arity_req` matches `args.length` and no required keywords;
          # Array-wrapped universal form otherwise. Wrong shape under NA
          # would reinterpret the Array via static_cast on the operand
          # type — visible UB. Used by from_attribute_write +
          # from_index_op_write; super has fundamentally different shape
          # (forwarding) and doesn't share this path. wrap_parens controls
          # whether the Array-wrapped form is itself parenthesised — purely
          # textual, preserved per call-site for byte-identical gen output.
          def na_or_wrap_args(name, args, wrap_parens: false)
            na_sig = emit&.natural_arity_names&.dig(name)
            if na_sig && na_sig.arity_req == args.length && na_sig.required_kw_names.empty?
              args.join(", ")
            else
              # UnivTag fence: universal path emits `univ, new Array(...)`.
              # wrap_parens kept as a no-op flag (the caller's own `()`
              # provides the necessary parens; an extra wrap would create
              # a comma-expression that silently drops `univ`).
              _ = wrap_parens
              "univ, new Array({#{args.join(", ")}})"
            end
          end

          # `arr[k] = v` parses as AttributeWrite(name=:[]=, receiver,
          # arg_nodes=[k, v]). Emit as a vtable call to op_aset via
          # the universal protocol. Arg shape via na_or_wrap_args.
          def from_attribute_write(node, locals)
            # Visibility: setter `obj.attr=` is a method call to `:attr=`
            # with the value as the single positional arg. Apply the same
            # visibility plumbing as from_method_call: explicit-other
            # receivers get recv_with_visibility_check (P2 raise /
            # P3 kind_of? check), and P4 calls are wrapped with
            # g_caller_self transport.
            prev_vis_name = @vis_check_name
            @vis_check_name = node.name
            begin
              recv_node = node.receiver_node
              recv_s = if recv_node.nil?
                "this"
              elsif recv_node.is_a?(Ast::SelfLiteral)
                from_expr(recv_node, locals)
              else
                recv_with_visibility_check(recv_node, locals)
              end
              args = (node.arg_nodes || []).map { |a| from_expr(a, locals) }
              cpp_name = Cpp.method_name(node.name)
              call_expr = "#{recv_s}->#{cpp_name}(#{na_or_wrap_args(node.name, args, wrap_parens: true)})"
              wrap_p4_caller_self_set(call_expr, recv_node: recv_node)
            ensure
              @vis_check_name = prev_vis_name
            end
          end

          # `arr[i] op= val` → `arr[i] = arr[i] op val`. Receiver and
          # indices evaluated once each; for `+=`, `-=`, etc.
          # `||=` / `&&=` not yet supported (need short-circuit).
          # Multi-index (`arr[i,j] += val`) emits as expected — op_aref/
          # op_aset with the full index list.
          def from_index_op_write(node, locals)
            op = node.operator
            raise EmissionError, "IndexOperatorWrite op :#{op} not yet supported" if %i[|| &&].include?(op)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            idx_strs = (node.index_arg_nodes || []).map { |a| from_arg(a, locals) }
            val_str = from_expr(node.value_node, locals)
            tag = next_tmp_id
            recv_t = "__iow_recv_#{tag}__"
            idx_array = "(new Array({#{idx_strs.join(", ")}}))"
            cpp_op = Cpp.method_name(op)
            # `recv->aref(idx) op val` → `recv->aset(idx, that)`. Op
            # arg shape via na_or_wrap_args.
            op_arg = na_or_wrap_args(op, [val_str])
            Cpp.block_expr(
              ["auto* #{recv_t} = #{recv_str};",
               "auto* _idx = #{idx_array};"],
              "#{recv_t}->op_aset(univ, new Array({#{idx_strs.join(", ")}, #{recv_t}->op_aref(univ, _idx)->#{cpp_op}(#{op_arg})}))"
            )
          end

          # `recv[idx] ||= val` — read once, return if truthy, else
          # `recv[idx] = val` and return val. Index list and receiver
          # evaluated once. Mirror of from_index_op_write but with
          # short-circuit truthiness instead of an arithmetic op.
          def from_index_or_write(node, locals)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            idx_strs = (node.index_arg_nodes || []).map { |a| from_arg(a, locals) }
            val_str = from_expr(node.value_node, locals)
            tag = next_tmp_id
            recv_t = "__iorw_recv_#{tag}__"
            cur_t = "__iorw_cur_#{tag}__"
            new_t = "__iorw_new_#{tag}__"
            idx_array = "(new Array({#{idx_strs.join(", ")}}))"
            Cpp.staged_block_expr([
              { stmts: ["auto* #{recv_t} = #{recv_str};",
                        "auto* #{cur_t} = #{recv_t}->op_aref(univ, #{idx_array});"],
                early_return: { cond: "truthy(#{cur_t})", value: cur_t } },
              { stmts: ["auto* #{new_t} = #{val_str};",
                        "#{recv_t}->op_aset(univ, new Array({#{idx_strs.join(", ")}, #{new_t}}));"],
                value: new_t }
            ])
          end

          # `recv[idx] &&= val` — read once, return if falsy, else
          # `recv[idx] = val` and return val.
          def from_index_and_write(node, locals)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            idx_strs = (node.index_arg_nodes || []).map { |a| from_arg(a, locals) }
            val_str = from_expr(node.value_node, locals)
            tag = next_tmp_id
            recv_t = "__iaw_recv_#{tag}__"
            cur_t = "__iaw_cur_#{tag}__"
            new_t = "__iaw_new_#{tag}__"
            idx_array = "(new Array({#{idx_strs.join(", ")}}))"
            Cpp.staged_block_expr([
              { stmts: ["auto* #{recv_t} = #{recv_str};",
                        "auto* #{cur_t} = #{recv_t}->op_aref(univ, #{idx_array});"],
                early_return: { cond: "!truthy(#{cur_t})", value: cur_t } },
              { stmts: ["auto* #{new_t} = #{val_str};",
                        "#{recv_t}->op_aset(univ, new Array({#{idx_strs.join(", ")}, #{new_t}}));"],
                value: new_t }
            ])
          end

          # `recv.b ||= val` — read recv.b once; return it if truthy;
          # otherwise assign recv.b = val and return val. Receiver evaluated
          # once. safe_nav: `recv&.b ||= val` short-circuits to nil if recv
          # is nil. The read is a no-arg method dispatch (default Array+kwargs+
          # block defaulting), the write is a 1-arg setter via NA or universal.
          def from_call_or_write(node, locals)
            from_call_short_circuit_write(node, locals, condition: "truthy")
          end

          # `recv.b &&= val` — read; return it if falsy; else write.
          def from_call_and_write(node, locals)
            from_call_short_circuit_write(node, locals, condition: "!truthy")
          end

          # Shared lowering for `||=` and `&&=` on method-call lvalues.
          # `condition` is the C++ predicate that triggers "short-circuit
          # to current": `truthy` for ||=, `!truthy` for &&=.
          def from_call_short_circuit_write(node, locals, condition:)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            val_str = from_expr(node.value_node, locals)
            read_cpp = Cpp.method_name(node.read_name)
            write_cpp = Cpp.method_name(node.write_name)
            tag = next_tmp_id
            recv_t = "__csw_recv_#{tag}__"
            cur_t = "__csw_cur_#{tag}__"
            new_t = "__csw_new_#{tag}__"
            read_args = na_or_wrap_args(node.read_name, [], wrap_parens: false)
            write_args = na_or_wrap_args(node.write_name, [new_t], wrap_parens: false)
            phases = []
            if node.safe_nav
              phases << {
                stmts: ["auto* #{recv_t} = #{recv_str};"],
                early_return: { cond: "#{recv_t} == nil_instance()", value: "nil_instance()" }
              }
              phases << {
                stmts: ["auto* #{cur_t} = #{recv_t}->#{read_cpp}(#{read_args});"],
                early_return: { cond: "#{condition}(#{cur_t})", value: cur_t }
              }
            else
              phases << {
                stmts: ["auto* #{recv_t} = #{recv_str};",
                        "auto* #{cur_t} = #{recv_t}->#{read_cpp}(#{read_args});"],
                early_return: { cond: "#{condition}(#{cur_t})", value: cur_t }
              }
            end
            phases << {
              stmts: ["auto* #{new_t} = #{val_str};",
                      "#{recv_t}->#{write_cpp}(#{write_args});"],
              value: new_t
            }
            Cpp.staged_block_expr(phases)
          end

          # `recv.b += val` (and -=/*=/etc.) — read once, compute
          # `current op val`, write back, return new value. The operator
          # dispatches as a method call on `current` (e.g. op_plus).
          def from_call_operator_write(node, locals)
            recv_str = node.receiver_node ? from_expr(node.receiver_node, locals) : "this"
            val_str = from_expr(node.value_node, locals)
            read_cpp = Cpp.method_name(node.read_name)
            write_cpp = Cpp.method_name(node.write_name)
            op_cpp = Cpp.method_name(node.operator)
            tag = next_tmp_id
            recv_t = "__cop_recv_#{tag}__"
            cur_t = "__cop_cur_#{tag}__"
            new_t = "__cop_new_#{tag}__"
            read_args = na_or_wrap_args(node.read_name, [], wrap_parens: false)
            op_args = na_or_wrap_args(node.operator, [val_str], wrap_parens: false)
            write_args = na_or_wrap_args(node.write_name, [new_t], wrap_parens: false)
            phases = []
            if node.safe_nav
              phases << {
                stmts: ["auto* #{recv_t} = #{recv_str};"],
                early_return: { cond: "#{recv_t} == nil_instance()", value: "nil_instance()" }
              }
              phases << {
                stmts: ["auto* #{cur_t} = #{recv_t}->#{read_cpp}(#{read_args});",
                        "auto* #{new_t} = #{cur_t}->#{op_cpp}(#{op_args});",
                        "#{recv_t}->#{write_cpp}(#{write_args});"],
                value: new_t
              }
            else
              phases << {
                stmts: ["auto* #{recv_t} = #{recv_str};",
                        "auto* #{cur_t} = #{recv_t}->#{read_cpp}(#{read_args});",
                        "auto* #{new_t} = #{cur_t}->#{op_cpp}(#{op_args});",
                        "#{recv_t}->#{write_cpp}(#{write_args});"],
                value: new_t
              }
            end
            Cpp.staged_block_expr(phases)
          end

          # Ruby's `&&` returns the last truthy value or the first falsy.
          # Lambda-wrap to evaluate left at most once.
          def from_and(node, locals)
            l = from_expr(node.left_node, locals)
            r = from_expr(node.right_node, locals)
            Cpp.block_expr(["auto* _l = #{l};"], "truthy(_l) ? (#{r}) : _l")
          end

          # Ruby's `||` returns the first truthy value, else the last.
          def from_or(node, locals)
            l = from_expr(node.left_node, locals)
            r = from_expr(node.right_node, locals)
            Cpp.block_expr(["auto* _l = #{l};"], "truthy(_l) ? _l : (#{r})")
          end

          # If-as-expression — `cond ? a : b` and `if cond; a; else; b; end`
          # are the same Ast::If. Plain C++ ternary (short-circuits, no
          # lambda needed). Multi-statement bodies become Ast::Sequence
          # which from_expr emits as comma-operator.
          # Missing else_node → nil (Ruby semantics).
          def from_if(node, locals)
            # Branches that contain Return / Break / Next / MASS / ForLoop
            # / While / Until can't be expressed as a ternary — from_expr
            # has no case for them (they're statement-only). Fall back
            # to a lambda + write_body form so they emit correctly
            # (write_body handles them; in a block context they throw,
            # otherwise they use C++ break/continue/return).
            if contains_return?(node.then_node) || contains_return?(node.else_node) ||
               contains_loop_escape?(node.then_node, allow_next: true) ||
               contains_loop_escape?(node.else_node, allow_next: true) ||
               contains_statement_only?(node.then_node) ||
               contains_statement_only?(node.else_node)
              return from_if_as_lambda(node, locals)
            end
            cond = from_expr(node.pred_node, locals)
            t = node.then_node ? from_expr(node.then_node, locals) : "nil_instance()"
            e = node.else_node ? from_expr(node.else_node, locals) : "nil_instance()"
            # Cast both arms to BO*. C++ ternary requires the
            # two arms to share a common type, which doesn't always
            # follow from Ruby semantics — e.g. `cond ? FooClass :
            # BarClass` produces &Foo_eigenclass* and &Bar_eigenclass*,
            # distinct C++ types with no implicit conversion. Both ARE
            # BO*-convertible (every emitted class derives from
            # BasicObject), so the explicit cast unifies them. Cheap.
            "(truthy(#{cond}) ? static_cast<BO*>(#{t}) : static_cast<BO*>(#{e}))"
          end

          # When one of these AST node kinds appears in expression
          # position (e.g. an if-as-expression's branch), from_expr has
          # no case for it — fall back to lambda + write_body form.
          # write_stmt handles them in statement position.
          def contains_statement_only?(node)
            return false unless node.is_a?(Ast::Node)
            return true if node.is_a?(Ast::MultipleAssignment) ||
                           node.is_a?(Ast::ForLoop) ||
                           node.is_a?(Ast::While) ||
                           node.is_a?(Ast::Until)
            # Stop at things that introduce their own scope.
            return false if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda) ||
                            node.is_a?(Ast::MethodDef) || node.is_a?(Ast::ClassDef) ||
                            node.is_a?(Ast::ModuleDef) || node.is_a?(Ast::SingletonClassDef)
            (node.respond_to?(:children) ? node.children : []).any? { |c| contains_statement_only?(c) }
          end

          def from_array_literal(node, locals)
            elems = node.element_nodes || []
            if elems.any? { |e| e.is_a?(Ast::SplatArg) }
              # `[a, *arr, b]` — flatten splats into a fresh Array
              # via lambda. splat_to_array enforces MRI semantics on
              # the splat value (Array fast-path, m_to_a coercion,
              # wrap-as-single fallback for non-Array non-respondable).
              push_lines = elems.map do |e|
                if e.is_a?(Ast::SplatArg)
                  "for (auto* _e : splat_to_array(#{from_expr(e.value_node, locals)})->data) _r->data.push_back(_e);"
                else
                  "_r->data.push_back(#{from_expr(e, locals)});"
                end
              end
              Cpp.block_expr(
                ["Array* _r = new Array();"] + push_lines,
                "_r",
                type: 'Array*'
              )
            else
              "(new Array({#{elems.map { |e| from_expr(e, locals) }.join(", ")}}))"
            end
          end

          # StringLiteral → (new String("...", N)). Bytes-and-length
          # ctor so embedded null bytes survive (`"a\0b"`). Escape
          # backslash, quote, newline, tab, null, and any non-printable
          # via octal — covers all byte values without depending on the
          # C++ source encoding.
          # `"foo #{x} bar"` → chain of String#+ calls. StringLiteral
          # parts emit directly; other parts coerce via m_to_s. The
          # whole chain starts from an empty String so an interpolated
          # string with no leading literal still yields a String*.
          def from_interpolated_string(node, locals)
            parts = node.parts || []
            return %((new String("", 0))) if parts.empty?
            chain = +%((new String("", 0)))
            parts.each do |part|
              part_str = if part.is_a?(Ast::StringLiteral)
                           from_string_literal(part)
                         else
                           "#{from_expr(part, locals)}->m_to_s(univ)"
                         end
              chain << "->op_plus(univ, new Array({#{part_str}}))"
            end
            "(#{chain})"
          end

          def from_string_literal(node)
            raw = node.value.raw  # Vm::StringObject -> raw bytes (Ruby String)
            "(new String(#{cpp_string_literal(raw)}, #{raw.bytesize}))"
          end

          # SymbolLiteral → intern("name"). intern() is a forward-declared
          # free function on the runtime that returns the canonical
          # Symbol* for a given name (interning).
          def from_symbol_literal(node)
            # node.value returns the raw Ruby Symbol (.value calls .raw).
            name = node.value.to_s
            escaped = name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
            %(intern("#{escaped}"))
          end

          # HashLiteral → (new Hash({{k,v}, {k,v}, ...})). **splat
          # entries (k=nil) are skipped — TODO when we hit a real case.
          def from_hash_literal(node, locals)
            pairs = (node.kv_nodes || []).reject { |k, _| k.nil? }
            elems = pairs.map { |k, v| "{#{from_expr(k, locals)}, #{from_expr(v, locals)}}" }
            "(new Hash({#{elems.join(", ")}}))"
          end

          # `(a..b)` / `(a...b)` literals — direct construction of a
          # Range with begin_/end_/exclude_end_ set. No m_new dispatch
          # since the literal already knows the values; matches how
          # ArrayLiteral and HashLiteral lower.
          def from_range_literal(node, locals)
            b = node.begin_node ? from_expr(node.begin_node, locals) : "nil_instance()"
            e = node.end_node   ? from_expr(node.end_node,   locals) : "nil_instance()"
            excl = node.exclusive ? "true" : "false"
            Cpp.block_expr(
              ["Range* _r = new Range();",
               "_r->begin_ = #{b};",
               "_r->end_ = #{e};",
               "_r->exclude_end_ = #{excl};",
               "_r->initialized_ = true;"],
              "_r"
            )
          end

          # `super` / `super(args)` — closed-world dispatch. The chain
          # of (origin, method) pairs in MRO order has been pre-baked
          # into super_context; we just walk one step further. Forwarding
          # super passes the current method's `args`/`kwargs`/`_block`
          # through; explicit super builds a fresh args array.
          # Super's parser folds explicit `super(x, foo: 99)` kwargs
          # into `kw_splat_nodes[0]` as a synthesized HashLiteral with
          # symbol keys. Reify those pairs as [key_node, value_node]
          # tuples — matches MethodCall#kw_arg_nodes shape so the
          # kw_unset codegen can fill slots uniformly. Variable splats
          # (**hash) stay in kw_splat_nodes; we don't unfold them here.
          def extract_super_kw_pairs(node)
            splats = node.respond_to?(:kw_splat_nodes) ? node.kw_splat_nodes : nil
            return [] if splats.nil? || splats.empty?
            head = splats.first
            return [] unless head.is_a?(Ast::HashLiteral)
            return [] unless head.kv_nodes.all? { |k, _| k.is_a?(Ast::SymbolLiteral) }
            head.kv_nodes
          end

          def from_super(node, locals)
            ctx = @super_context
            raise EmissionError, "super used outside a method body" unless ctx
            chain = ctx[:chain]
            next_idx = ctx[:origin_index] + 1
            raise EmissionError, "super: no superclass method '#{ctx[:method_name]}' for #{ctx[:host_name]}" if next_idx >= chain.size
            next_origin, _ = chain[next_idx]
            # Pick the qualifying class for the C++ call:
            #  - Module origin: slot lives on the host as sm_X__from_<Origin>.
            #  - Class origin:  use C++ inheritance directly — `this->Parent::m_X(...)`.
            #  - :self origin can only appear at idx=0 (and we're past it).
            qualifier_class = ctx[:host_name]
            cpp_name =
              if next_origin.is_a?(Vm::ClassObject)
                qualifier_class = next_origin.full_name.to_s.gsub("::", "_")
                Cpp.method_name(ctx[:method_name])
              elsif next_origin == :self
                Cpp.method_name(ctx[:method_name])
              else
                Cpp.shadowed_method_name(ctx[:method_name], next_origin)
              end
            # Natural-arity super. The enclosing method's name is
            # eligible iff its body is natural-arity; the super
            # target is the same Ruby name on a different class so
            # it's also natural-arity. Pass positional args directly,
            # bypassing the universal Array allocation.
            method_name = ctx[:method_name]
            na_sig = emit&.natural_arity_names&.dig(method_name)
            if na_sig
              # Forwarding super needs the kw locals too — they live
              # under their declared param names (l_<kw_name>) and
              # come after the positional locals in the signature.
              kw_locals = na_sig.required_kw_names.map { |kn| MethodEmitter.local_cpp_name(kn) }
              args_csv =
                if node.forwarding
                  # Bare `super` — forward the enclosing method's
                  # named params. ctx[:method_params] holds the
                  # positionals; append kw locals in sig order.
                  ((ctx[:method_params] || []) + kw_locals).join(', ')
                elsif node.arg_nodes.empty?
                  # `super()` with no args — only legal if parent
                  # has zero slots. Kw-bearing parent will fail to
                  # compile (too few args), which is the right
                  # outcome.
                  ""
                else
                  # Explicit `super(x, y)` — pass the given args.
                  # If enclosing has kw, parent expects them too;
                  # we forward the enclosing's kw locals. This
                  # matches Ruby semantics for explicit super in a
                  # method whose parent shares the kw signature.
                  pos = node.arg_nodes.map { |a| from_expr(a, locals) }
                  (pos + kw_locals).join(', ')
                end
              return "this->#{qualifier_class}::#{cpp_name}(#{args_csv})"
            end
            # Multi-arity super: forward all bound params (required +
            # optional, defaults filled if not caller-supplied) to the
            # chain shadow at the full arity. Ruby semantics — bare
            # super propagates the current method's bound state.
            mu_family = emit&.multi_arity_table&.dig(method_name)
            if mu_family
              args_csv =
                if node.forwarding
                  (ctx[:method_params] || []).join(', ')
                elsif node.arg_nodes.empty?
                  ""
                else
                  node.arg_nodes.map { |a| from_expr(a, locals) }.join(', ')
                end
              return "this->#{qualifier_class}::#{cpp_name}(#{args_csv})"
            end
            # Kw-unset super: parent slot has the same uniform slot
            # signature (required pos → opt pos → kws sorted). Bare
            # `super` forwards all positionals + all kw locals (each
            # already either caller-bound or default-filled in this
            # entry). Explicit super(...) with kw overrides — pass
            # provided args and look up kw locals from the current
            # method's bound state.
            kw_sig = emit&.kw_unset_table&.dig(method_name)
            if kw_sig
              all_kw_locals = kw_sig.all_kw_names.map { |kn| MethodEmitter.local_cpp_name(kn) }
              # Super has no kw_arg_nodes accessor — the parser folds
              # explicit `foo: 99` super args into kw_splat_nodes[0]
              # as a synthesized HashLiteral. Reify those pairs for
              # the UNSET slot-fill below.
              super_kw_pairs = extract_super_kw_pairs(node)
              args_csv =
                if node.forwarding
                  ((ctx[:method_params] || []) + all_kw_locals).join(', ')
                elsif node.arg_nodes.empty? && super_kw_pairs.empty?
                  ""
                else
                  pos = node.arg_nodes.map { |a| from_expr(a, locals) }
                  # Pad positionals up to arity_req + opt with UNSET.
                  pad = Array.new(kw_sig.arity_req + kw_sig.opt - pos.length, "unset_instance()")
                  call_kw_map = super_kw_pairs.each_with_object({}) do |(k, v), h|
                    kn = k.respond_to?(:value) ? k.value.to_sym : nil
                    h[kn] = v if kn
                  end
                  kw_vals = kw_sig.all_kw_names.map do |kn|
                    if call_kw_map.key?(kn)
                      from_expr(call_kw_map[kn], locals)
                    else
                      MethodEmitter.local_cpp_name(kn)
                    end
                  end
                  (pos + pad + kw_vals).join(', ')
                end
              return "this->#{qualifier_class}::#{cpp_name}(#{args_csv})"
            end

            args_expr =
              if node.forwarding
                "args"
              elsif node.arg_nodes.empty?
                "(&EMPTY_ARGS)"
              else
                arg_strs = node.arg_nodes.map { |a| from_expr(a, locals) }
                "(new Array({#{arg_strs.join(', ')}}))"
              end
            # Ruby semantics: bare `super` forwards everything (incl
            # outer kwargs); explicit `super(...)` does NOT implicitly
            # forward kwargs — they're empty unless the call has an
            # explicit `**splat`. Previously we always passed outer
            # `kwargs`, which silently appended the outer kwargs Hash
            # as a trailing positional arg in the parent body (via the
            # has_kw=false fold) — invisible until the arity check
            # surfaced it.
            kwargs_expr =
              if node.forwarding
                "kwargs"
              elsif (node.respond_to?(:kw_splat_nodes) ? node.kw_splat_nodes : []).empty?
                "(&EMPTY_KWARGS)"
              else
                # **splat forwarding from explicit super — not yet
                # lowered; fall back to passing the outer kwargs hash,
                # which preserves any inner kwarg state (and matches
                # the previous behaviour). Tracked separately.
                "kwargs"
              end
            block_expr =
              if node.block_node.nil?
                "_block"
              elsif node.block_node.is_a?(Ast::BlockArg)
                from_block_as_proc(node.block_node, locals)
              else
                "static_cast<Proc*>(#{from_expr(node.block_node, locals)})"
              end
            # Direct C++ method call — bypasses the usual virtual
            # dispatch since we resolved the target at AOT time.
            "this->#{qualifier_class}::#{cpp_name}(univ, #{args_expr}, #{kwargs_expr}, #{block_expr})"
          end

          # Box-first global variable reads. Match-data globals stay
          # special-cased (no GLOBALS hash entry — they thread through
          # g_last_match()). Everything else lowers to a GLOBALS hash
          # lookup. $LOAD_PATH-family and $LOADED_FEATURES-family auto-
          # init to a fresh empty Vm::ArrayObject if absent — matches
          # MRI's "always an Array" guarantee that callers like
          # `[core_path] + $LOAD_PATH` rely on.
          GLOBAL_NAME_ALIAS = {
            :"$:"  => "$LOAD_PATH",
            :"$-I" => "$LOAD_PATH",
            :"$\"" => "$LOADED_FEATURES",
          }.freeze
          GLOBAL_ARRAY_NAMES = %w[$LOAD_PATH $LOADED_FEATURES].to_set.freeze

          def from_global_variable_read(node)
            case node.name
            when :"$~"
              return "g_last_match()"
            when /\A\$(\d+)\z/
              n = ::Regexp.last_match(1).to_i
              return "matchdata_cap(g_last_match(), #{n})"
            end
            canonical = GLOBAL_NAME_ALIAS[node.name] || node.name.to_s
            name_lit = cpp_string_literal(canonical)
            if GLOBAL_ARRAY_NAMES.include?(canonical)
              # Auto-init helper: returns existing entry, or a fresh
              # empty Vm::ArrayObject (also stored back into GLOBALS).
              "g_global_array(#{name_lit})"
            else
              # Plain hash lookup — nil for missing.
              "g_global_or_nil(#{name_lit})"
            end
          end

          # GLOBALS hash store. For Symbol-keyed globals like $LOAD_PATH
          # the key matches the AST evaluator's canonical name (after
          # alias normalisation).
          def from_global_variable_write(node, locals)
            canonical = GLOBAL_NAME_ALIAS[node.name] || node.name.to_s
            name_lit = cpp_string_literal(canonical)
            "g_global_set(#{name_lit}, #{from_expr(node.value_node, locals)})"
          end

          # `/pattern/flags` — direct construction of a Regexp at the
          # call site. The pattern compiles via the same path as
          # `Regexp.new` (m_initialize → onig_new). For frequently-
          # evaluated literals we'd want a static cache (compile once at
          # __init_static_state__), but the WQ parser's regexes are
          # evaluated mostly during construction, so per-eval is fine
          # for now.
          def from_regexp_literal(node)
            src_bytes = node.source.to_s.bytes
            literal = "(new String(#{cpp_string_literal(node.source.to_s)}, #{src_bytes.size}))"
            Cpp.block_expr(
              ["Regexp* _re = new Regexp();",
               "Array* _a = new Array({static_cast<BO*>(#{literal}), static_cast<BO*>(new Integer(#{node.flags.to_i}))});",
               "_re->m_initialize(univ, _a);"],
              "_re"
            )
          end

          # `/foo#{bar}baz/` — build the source String at runtime by
          # concatenating literal chunks + interpolated expressions
          # (each .to_s'd), then construct the Regexp from source +
          # flags. Same shape as from_interpolated_string for the
          # source build, then wraps in onig_new via Regexp::m_initialize.
          def from_interpolated_regexp_literal(node, locals)
            parts = node.parts || []
            chain = +%((new String("", 0)))
            parts.each do |part|
              part_str = if part.is_a?(Ast::StringLiteral)
                           from_string_literal(part)
                         else
                           "#{from_expr(part, locals)}->m_to_s(univ)"
                         end
              chain << "->op_plus(univ, new Array({#{part_str}}))"
            end
            Cpp.block_expr(
              ["Regexp* _re = new Regexp();",
               "Array* _a = new Array({static_cast<BO*>(#{chain}), static_cast<BO*>(new Integer(#{node.flags.to_i}))});",
               "_re->m_initialize(univ, _a);"],
              "_re"
            )
          end

          # Float literal — Ruby's Float::INFINITY / Float::NAN
          # interpolate to "Infinity" / "NaN" which aren't C++ literals.
          # Use the standard C++ macros for those, plain digits for finite.
          def float_literal(v)
            return "(new Float(std::numeric_limits<double>::infinity()))" if v == Float::INFINITY
            return "(new Float(-std::numeric_limits<double>::infinity()))" if v == -Float::INFINITY
            return "(new Float(std::numeric_limits<double>::quiet_NaN()))" if v.is_a?(Float) && v.nan?
            "(new Float(#{v}))"
          end

          # Leaf-only emission: value-types, class/module refs, and the
          # inline-constructed Regexp/Proc snapshots. These need no shared
          # materialization — interned (Integer/Symbol), singleton
          # (nil/true/false), address-of (&Foo_CLASS), or rarely-shared
          # (Regexp/Proc). The Snapshot graph serializer calls this for
          # the leaves of the object graph; String/Array/Hash/ObjectObject
          # are NOT leaves and must go through a snapshot slot.
          def emit_leaf(val)
            case val
            when Vm::IntegerObject then intern_int(val.raw)
            when Vm::FloatObject   then float_literal(val.raw)
            when Vm::SymbolObject  then "intern(#{cpp_string_literal(val.raw.to_s)})"
            when Vm::NilObject     then "nil_instance()"
            when Vm::TrueObject    then "true_instance()"
            when Vm::FalseObject   then "false_instance()"
            when Vm::RegexpObject
              src = val.raw.source
              flags = val.raw.options
              Cpp.block_expr(
                ["Regexp* _re = new Regexp();",
                 "Array* _a = new Array({static_cast<BO*>((new String(#{cpp_string_literal(src)}, #{src.bytesize}))), static_cast<BO*>(new Integer(#{flags}))});",
                 "_re->m_initialize(univ, _a);"],
                "_re"
              )
            when Vm::ClassObject, Vm::ModuleObject
              flat = class_object_to_flat(val)
              raise EmissionError, "emit_leaf: #{val.class.name.split('::').last} #{val.full_name} not in emitted set" unless flat
              format_constant(flat)
            when Vm::ProcObject
              loc = val.block_object&.source_location || ["unknown", 0]
              %{(new Proc([](Array*, Hash*) -> BO* { /* snapshot Proc placeholder, defined at #{loc[0]}:#{loc[1]} */ return nil_instance(); }))}
            else
              raise EmissionError, "emit_leaf: #{val.class.name} is not a leaf value (String/Array/Hash/ObjectObject must be snapshot-slotted)"
            end
          end

          # Large Integer-only arrays: emit values as a static int64_t[]
          # and build the Array at runtime (compact source + cheap parse).
          # Returns the build expression, registering the table; nil if the
          # array doesn't qualify (caller emits elementwise).
          def int_array_build_expr(raw_elems)
            return nil unless raw_elems.size > INT_ARRAY_THRESHOLD && raw_elems.all? { |e| e.is_a?(Vm::IntegerObject) }
            idx = @raw_int_arrays.size
            @raw_int_arrays << raw_elems.map(&:raw)
            "build_int_array(__TBL_INT_#{idx}__, #{raw_elems.size})"
          end

          # Render a Vm value as a C++ expression that produces the
          # equivalent box at runtime. With a Snapshot attached, slottable
          # objects route to their canonical snapshot accessor (identity-
          # preserving); leaves go inline via emit_leaf. Without a snapshot
          # (unit tests / legacy), constructs inline as before.
          def emit_vm_value(val)
            return @snapshot.ref_expr(val) if @snapshot
            case val
            when Vm::IntegerObject then intern_int(val.raw)
            when Vm::FloatObject   then float_literal(val.raw)
            when Vm::SymbolObject  then "intern(#{cpp_string_literal(val.raw.to_s)})"
            when Vm::StringObject  then "(new String(#{cpp_string_literal(val.raw)}, #{val.raw.bytesize}))"
            when Vm::NilObject     then "nil_instance()"
            when Vm::TrueObject    then "true_instance()"
            when Vm::FalseObject   then "false_instance()"
            when Vm::ArrayObject
              # Specialise large Integer-only arrays: emit the values
              # as a static `int64_t[]` and build the Array at runtime.
              # Saves ~3x source size vs `(&_f_i_X), ...` per element
              # and lets cc1plus parse the table as cheap static data.
              if val.raw.size > INT_ARRAY_THRESHOLD && val.raw.all? { |e| e.is_a?(Vm::IntegerObject) }
                idx = @raw_int_arrays.size
                @raw_int_arrays << val.raw.map(&:raw)
                "build_int_array(__TBL_INT_#{idx}__, #{val.raw.size})"
              else
                elems = val.raw.map { |e| emit_vm_value(e) }
                "(new Array({#{elems.join(", ")}}))"
              end
            when Vm::HashObject
              pairs = val.raw.map { |k, v| "{#{emit_vm_value(k)}, #{emit_vm_value(v)}}" }
              "(new Hash({#{pairs.join(", ")}}))"
            when Vm::RegexpObject
              # Same shape as from_regexp_literal but seeded from the captured
              # value's source + options (raw.source / raw.options).
              src = val.raw.source
              flags = val.raw.options
              Cpp.block_expr(
                ["Regexp* _re = new Regexp();",
                 "Array* _a = new Array({static_cast<BO*>((new String(#{cpp_string_literal(src)}, #{src.bytesize}))), static_cast<BO*>(new Integer(#{flags}))});",
                 "_re->m_initialize(univ, _a);"],
                "_re"
              )
            when Vm::ClassObject, Vm::ModuleObject
              flat = class_object_to_flat(val)
              raise EmissionError, "emit_vm_value: #{val.class.name.split('::').last} #{val.full_name} not in emitted set" unless flat
              # Route through format_constant so fused classes
              # (Frozone_Vm_NilObject etc.) redirect to the runtime
              # singleton (&NilClass_CLASS) — the flat name is filtered
              # from emission, but the runtime equivalent exists.
              format_constant(flat)
            when Vm::ProcObject
              # Snapshot Proc captured from a user_constant (typically
              # a Hash like OptionParser::Officious that holds
              # callbacks). Emitting the captured body as a real C++
              # lambda would need scope-walking + free-variable
              # resolution that we don't yet do at static-init time,
              # so for now emit a placeholder Proc whose body returns
              # nil. The enclosing Hash structure / iteration still
              # works; calls go through but are no-ops. We can't
              # abort here because some callbacks (e.g.
              # OptionParser::Officious['version']) get invoked
              # during normal startup paths the user may not exercise
              # — aborting on the placeholder breaks unrelated
              # programs. Source location is captured in the lambda
              # comment for debuggability.
              loc = val.block_object&.source_location || ["unknown", 0]
              %{(new Proc([](Array*, Hash*) -> BO* { /* snapshot Proc placeholder, defined at #{loc[0]}:#{loc[1]} */ return nil_instance(); }))}
            when Vm::ObjectObject
              # If this object is itself one of our registered user
              # constants, emit a reference to its accessor (its ivars
              # are populated by static_state_init).
              flat = @user_constants.find { |_, v| v.equal?(val) }&.first
              raise EmissionError, "emit_vm_value: ObjectObject (#{val.class_object&.full_name}) not in user_constants" unless flat
              "k_#{flat}()"
            else
              raise EmissionError, "emit_vm_value: unsupported VM value class #{val.class.name}"
            end
          end

        end
      end
    end
  end
end
