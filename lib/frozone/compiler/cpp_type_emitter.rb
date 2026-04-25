module Frozone
  module Compiler
    # Centralised TI Type → cpp string rendering per emission slot context.
    #
    # The C++ emitter has many sites where a TI Type needs to become a cpp
    # text fragment, and the right rendering depends on the slot context:
    # method return needs different treatment than ivar decl needs different
    # treatment than hoisted local needs different treatment than hash
    # literal V template arg.
    #
    # Previously each site reimplemented the decision tree (gc_ref vs
    # gc_local, optional<T> vs raw, default value choice, what to do on
    # bottom/nil). Inevitably they drifted: one site forgot a nullable
    # check, another defaulted to int64_t while a sibling used
    # RubyObject*, etc. — the "paper cuts" the strict-TI / no-auto push
    # kept tripping on.
    #
    # This module is the single source of truth. Each `for_*` method is a
    # pure function: takes a Type (or nil), returns the cpp string
    # appropriate for that slot context. Callers in cpp_emitter.rb do the
    # actual writing and any side-effects (tracking @_boxed_ivars, marking
    # @_pointer_locals, etc.). The formatter has no state.
    #
    # See feedback_no_auto_in_cpp.md and project_radical_box_first.md for
    # the design context. Stage 1 of the box-first plan.
    module CppTypeEmitter
      module_function

      # ---- Method return type ----------------------------------------

      # Cpp type for a method return slot (`X foo() { ... }`).
      # Nil/bottom → "auto" today; the strict-TI work has the emit_method
      # path skip-or-stub instead, so this branch is only reached from
      # the legacy/raw-return paths during the migration.
      def for_return(ty)
        return "auto" if ty.nil? || ty.bottom?
        return ty.to_cpp if ty.renders_as_optional?
        return ty.to_cpp_ref if ty.emitted_as_pointer?
        return ty.to_cpp_ref if container_render?(ty)
        return ty.to_cpp_ref if ty.array_scalar?
        "auto"
      end

      # Cpp expression for an implicit/falling-through nil return when the
      # method's declared return type is `ret_ty`. Pointer slots → bare
      # `nullptr` typed as the slot's gc_ref<T>; optional → `std::nullopt`;
      # value-typed slots → default-construct via `T(RUBY_NIL)`.
      def nil_return_expr(ret_ty)
        return "RUBY_NIL" unless ret_ty
        return "std::nullopt" if ret_ty.renders_as_optional?
        return "#{ret_ty.to_cpp_ref}(nullptr)" if ret_ty.emitted_as_pointer?
        "#{ret_ty.to_cpp}(RUBY_NIL)"
      end

      # ---- Param decl ------------------------------------------------

      # Cpp type for a required-param decl (`X p`). Pointer slots commit
      # to gc_ref<T> (so callers passing Root<T> implicitly convert);
      # other types stay `auto` for caller-side deduction.
      def for_param(ty)
        return "auto" if ty.nil? || ty.bottom?
        return ty.to_cpp_ref if ty.emitted_as_pointer?
        "auto"
      end

      # Cpp type for an optional-param `nil` default (`X p = nullptr`).
      # Same rule as for_param — pointer slots commit, others stay auto.
      def for_optional_nil_param(ty)
        return "auto" if ty.nil? || ty.bottom?
        return ty.to_cpp_ref if ty.emitted_as_pointer?
        "auto"
      end

      # ---- Local-variable decl --------------------------------------

      # Cpp type for a hoisted local-variable decl (`X name = init;`).
      # Pointer slots use `gc_local<T>` (Root<T> under Dustman) so the
      # stack slot acts as a GC root; non-pointer types use `gc_ref<T>`
      # (= raw T* under Boehm/none) — a passive reference. Returns nil
      # on bottom — caller can fall back to decltype(rhs).
      def for_local(ty)
        return nil if ty.nil? || ty.bottom?
        return ty.to_cpp_local if ty.emitted_as_pointer?
        ty.to_cpp_ref
      end

      # Init expression suffix for a local-variable decl (e.g. ` = 0`,
      # ` = 0.0`, ` = false`, ` = nullptr`, or "" for no init). Same
      # logic applies to ivar field decls.
      def init_suffix(ty)
        return " = nullptr" if ty&.emitted_as_pointer?
        return " = 0"   if integer_default?(ty)
        return " = 0.0" if float_default?(ty)
        return " = false" if bool_default?(ty)
        ""
      end

      # ---- Ivar decl -----------------------------------------------

      # Cpp type for an ivar field decl (`X iv_name = init;`). Pointer
      # slots use `gc_ref<T>` (heap slots, not stack roots — gc_local
      # would be wrong here). Returns nil on bottom — caller falls back
      # to BOXED_FALLBACK and tracks the boxing.
      def for_ivar(ty)
        return nil if ty.nil? || ty.bottom?
        ty.to_cpp_ref
      end

      # ---- Coercion target -----------------------------------------

      # Cpp type for a coercion target (a slot that an expression needs
      # to be coerced into). Pointer slots → gc_ref<T> wrapper; other
      # types render as their normal cpp form.
      def for_coerce_target(ty)
        return nil if ty.nil? || ty.bottom?
        return ty.to_cpp_ref if ty.emitted_as_pointer?
        ty.to_cpp
      end

      # ---- Hash literal element -------------------------------------

      # Cpp type for a Hash<K, V> value template arg. Pointer V types
      # propagate gc_ref so storage holds the right kind of slot.
      def for_hash_val_template(ty)
        ty.to_cpp_ref
      end

      # Cpp type for a Hash<K, V> value RHS context (the case/when arm
      # selecting how to box the assigned value at .store sites).
      def for_hash_val_rhs(ty)
        ty.to_cpp
      end

      # ---- Universal fallback ---------------------------------------

      # The "boxed any" rendering when TI couldn't commit to a concrete
      # type at a slot that genuinely needs one (e.g. an ivar of unknown
      # type — rather than silently emitting int64_t).
      BOXED_FALLBACK = "gc_ref<RubyObject>".freeze
      BOXED_FALLBACK_INIT = " = nullptr".freeze

      # ---- Internal predicates --------------------------------------

      def container_render?(ty)
        return false unless ty.class_type?
        ty.array_like? || %i[Hash String Symbol].include?(ty.class_name)
      end

      def integer_default?(ty)
        return false unless ty
        ty.i64? || (ty.class_type? && %i[Integer Numeric].include?(ty.class_name) && !ty.nullable?)
      end

      def float_default?(ty)
        return false unless ty
        ty.f64? || (ty.class_type? && ty.class_name == :Float && !ty.nullable?)
      end

      def bool_default?(ty)
        return false unless ty
        ty.class_type? && %i[TrueClass FalseClass].include?(ty.class_name)
      end
    end
  end
end
