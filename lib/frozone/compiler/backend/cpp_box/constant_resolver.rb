# Box-first constant lookup and formatting.
#
# Ruby constant lookup is lexical — `Diagnostic::Engine` referenced
# inside `Parser::Base` tries `Parser::Base::Diagnostic::Engine`,
# then `Parser::Diagnostic::Engine`, then `Diagnostic::Engine`. Box-
# first emits each class as a flat C++ identifier (`Parser_Base`,
# `Parser_Diagnostic_Engine`), so resolution walks the lexical scope
# chain (innermost-first) joining with `_` and looks up in the
# `user_classes` / `user_constants` registries.
#
# Two surfaces:
# - Static path (parent is itself a constant) → resolved at AOT
#   time, formatted as `(&Foo_Bar_CLASS)` for class refs or
#   `k_Foo_Bar()` for value constants.
# - Dynamic parent (`expr.class::CONST`, `self::X`) → routed through
#   the per-class `c_X` virtual on the eigenclass (constant-side
#   analogue of `m_X` method dispatch).
#
# Mixed into Cpp so call sites stay unchanged.

module Frozone
  module Compiler
    module Backend
      module CppBox
        module ConstantResolver
          DEFINED_LITERAL_RESULT = {
            self:        "self",
            nil:         "nil",
            true:        "true",
            false:       "false",
            literal:     "expression",
            expression:  "expression",
            assignment:  "assignment",
            local_var:   "local-variable",
            ivar:        "instance-variable",
          }.freeze

          def from_defined_expr(node, locals)
            kind = node.kind
            if (lit = DEFINED_LITERAL_RESULT[kind])
              # Trivial / closed-world-known cases. `:ivar` is always
              # truthy here because every ivar that compiles into the
              # body has a backing field initialised to nil_instance —
              # which Ruby treats as "assigned" for defined? purposes.
              return %((new String("#{lit}", #{lit.bytesize})))
            end
            if kind == :constant
              # Closed-world: resolve the constant statically. If it's
              # known to the AOT registry, the answer is "constant";
              # otherwise nil. (Runtime constant_missing is not a
              # consideration here — every reachable constant is in
              # user_constants / user_classes by emission time.)
              return defined_constant_result(node.extra)
            end
            if kind == :yield
              # Block presence is the runtime predicate.
              return %|(_block != nullptr ? static_cast<BasicObject*>(new String("yield", 5)) : nil_instance())|
            end
            if kind == :method
              # `defined?(receiver.method_name)` → "method" if respond_to?,
              # else nil. Implicit receiver uses `this`, which for our
              # purposes is the current self. Wrap in a try because
              # receiver evaluation itself can raise (e.g. nil receiver).
              receiver_node, method_name, _receiver_check = node.extra
              recv = receiver_node ? from_expr(receiver_node, locals) : "this"
              # Use the boolean form of respond_to? — mm_respond_to_q
              # returns true_instance/false_instance.
              return %|([&]() -> BasicObject* { try { return truthy(#{recv}->mm_respond_to_q(new Array({intern(#{cpp_string_literal(method_name.to_s)})}))) ? static_cast<BasicObject*>(new String("method", 6)) : nil_instance(); } catch (...) { return nil_instance(); } }())|
            end
            raise Cpp::EmissionError, "defined?(#{kind}) not yet supported in box-first"
          end

          # Closed-world `defined?(Const)` answer. ConstantRead /
          # ConstantPath get statically resolved through the same
          # walker the value-side uses; any other shape (e.g. a
          # transformed expression) falls back to nil — consistent
          # with "not statically known means not present in this
          # build".
          def defined_constant_result(extra)
            resolved = case extra
                       when Ast::ConstantRead then resolve_constant([extra.name.to_s])
                       when Ast::ConstantPath then defined_constant_path_resolved(extra)
                       end
            resolved ? %((new String("constant", 8))) : "nil_instance()"
          end

          def defined_constant_path_resolved(node)
            return nil unless static_constant_parent?(node.parent_node)
            parts = collect_path(node)
            absolute = parts.first == "" ||
                       node.parent_node.is_a?(Ast::RootNamespaceNode)
            absolute ? resolve_top_level(parts.reject(&:empty?)) : resolve_constant(parts)
          end

          # ConstantRead / ConstantPath — Ruby-style lookup walks the
          # lexical scope chain. For `Diagnostic::Engine` written inside
          # `Parser::Base`, try `Parser::Base::...`, then `Parser::...`,
          # then top-level `...`. First match in user_classes /
          # user_constants wins. Callers format the result.
          def from_constant_read(node) = format_constant(resolve_constant([node.name.to_s]) ||
            (raise Cpp::EmissionError, "ConstantRead: unresolved constant :#{node.name}"))

          # `FOO = expr` — rebind a user_constant's storage cell.
          # build_user_constant_accessors emits non-fused accessors as
          # `BasicObject*& k_FOO()` returning a reference into the
          # static cell, so `(k_FOO() = value)` rebinds it. Fused
          # singletons (NIL/TRUE/FALSE) and class-CLASS singletons aren't
          # writable storage — raise so callers see the gap.
          def from_constant_write(node, locals)
            flat = resolve_constant([node.name.to_s]) ||
              (raise Cpp::EmissionError, "ConstantWrite: unresolved constant :#{node.name}")
            ensure_writable_constant!(flat, "ConstantWrite")
            "(k_#{flat}() = #{from_expr(node.value_node, locals)})"
          end

          # `Foo::Bar = expr` — same as ConstantWrite but the target is
          # path-resolved. Only static-parent paths (parent is a constant
          # shape) are supported; dynamic-parent writes (e.g. `expr::X = …`)
          # would need a runtime constant-set surface that doesn't yet
          # exist.
          def from_constant_path_write(node, locals)
            parent = node.parent_node
            unless static_constant_parent?(parent)
              raise Cpp::EmissionError, "ConstantPathWrite: dynamic parent (#{parent.class.name}) not supported"
            end
            parts = collect_path(parent) + [node.name.to_s]
            absolute = parts.first == "" || parent.is_a?(Ast::RootNamespaceNode)
            flat = absolute ? resolve_top_level(parts.reject(&:empty?)) : resolve_constant(parts)
            unless flat
              raise Cpp::EmissionError, "ConstantPathWrite: unresolved path #{parts.join('::')}"
            end
            ensure_writable_constant!(flat, "ConstantPathWrite")
            "(k_#{flat}() = #{from_expr(node.value_node, locals)})"
          end

          # Fused singletons + class-CLASS singletons are not writable
          # storage — they're returned by-value or as address-of-static.
          # Raising here keeps the runtime abort message specific.
          def ensure_writable_constant!(flat, kind)
            if FUSED_CONSTANT_TARGETS.key?(flat) || FUSED_CLASS_TARGETS.key?(flat)
              raise Cpp::EmissionError, "#{kind}: target #{flat} is a fused singleton — not writable"
            end
            unless @user_constants.key?(flat)
              raise Cpp::EmissionError, "#{kind}: target #{flat} is not a user_constant — not writable (class CLASS singleton or runtime-only)"
            end
          end

          def from_constant_path(node)
            # Dynamic parent receiver (e.g. `self.class::CONST`,
            # `expr.class::CONST`) — the receiver class isn't known at
            # compile time, so go through the c_X virtual on the
            # eigenclass. This is the constant-side analogue of m_X
            # method dispatch, populated from the dynamic-constant
            # surface set.
            unless static_constant_parent?(node.parent_node)
              # c_X is on BasicObject's universal surface (see
              # write_universal_surface) — the eigenclass override
              # returns the constant; everyone else falls through to
              # constant_missing. So no cast needed; this works when
              # the receiver is genuinely a class (`self.class::X`),
              # genuinely a module (`self::X` in a module method), or
              # even a wrong-typed object (graceful constant_missing
              # rather than UB).
              recv = from_expr(node.parent_node, Set.new)
              return "(#{recv})->c_#{node.name}()"
            end
            parts = collect_path(node)
            absolute = parts.first == "" ||
                       (node.respond_to?(:parent_node) && node.parent_node.is_a?(Ast::RootNamespaceNode))
            resolved = absolute ? resolve_top_level(parts.reject(&:empty?)) : resolve_constant(parts)
            return format_constant(resolved) if resolved
            # Static resolution failed. If the parent itself resolves,
            # fall back to runtime c_X dispatch — `M::UNDEFINED`
            # then reaches const_missing (NameError) at runtime instead
            # of getting AOT-skipped. Absolute paths (Root) without a
            # resolution stay an EmissionError — there's no parent
            # receiver to dispatch through.
            raise Cpp::EmissionError, "ConstantPath: unresolved path #{parts.join('::')}" if absolute
            recv = from_expr(node.parent_node, Set.new)
            "(#{recv})->c_#{node.name}()"
          end

          # True when the parent of a ConstantPath is itself a const-shape
          # node — only those are statically resolvable. Anything else
          # (a method call, local var, etc.) needs runtime dispatch.
          def static_constant_parent?(parent)
            parent.is_a?(Ast::ConstantRead) ||
              parent.is_a?(Ast::ConstantPath) ||
              parent.is_a?(Ast::RootNamespaceNode)
          end

          # Walk the method's lexical scope chain (innermost-first),
          # trying each prefix joined with `parts`. Falls back to the
          # top-level (bare path) lookup last. Returns the resolved
          # flat name as a Symbol (e.g. `:Parser_Diagnostic_Engine`),
          # or nil if no scope yields a match.
          def resolve_constant(parts)
            (scope_prefixes + [[]]).each do |prefix|
              flat = (prefix + parts).join("_").to_sym
              return flat if @user_constants.key?(flat) || instantiable_class?(flat) ||
                             FUSED_CONSTANT_TARGETS.key?(flat)
            end
            nil
          end

          def resolve_top_level(parts)
            flat = parts.join("_").to_sym
            (@user_constants.key?(flat) || instantiable_class?(flat) ||
              FUSED_CONSTANT_TARGETS.key?(flat)) ? flat : nil
          end

          # Phase 2 fusion: Frozone::Vm::{Nil,False,True}Object are the
          # interpreter's host-Ruby class declarations for nil/false/true.
          # In compiled mode they collapse into the runtime's nil/false/
          # true classes — so a reference to NilObject is just NilClass,
          # NilObject::NIL is just nil_instance(), etc. Same for
          # FalseObject/TrueObject. Maps are scoped here to keep
          # format_constant the single point of resolution.
          FUSED_CLASS_TARGETS = {
            Frozone_Vm_NilObject:   "NilClass",
            Frozone_Vm_FalseObject: "FalseClass",
            Frozone_Vm_TrueObject:  "TrueClass",
          }.freeze
          FUSED_CONSTANT_TARGETS = {
            Frozone_Vm_NilObject_NIL:    "nil_instance()",
            Frozone_Vm_FalseObject_FALSE: "false_instance()",
            Frozone_Vm_TrueObject_TRUE:  "true_instance()",
          }.freeze

          # Format a resolved Symbol as the right C++ expression:
          # accessor call for value constants, address-of-singleton for
          # classes.
          def format_constant(name)
            if (runtime_inst = FUSED_CONSTANT_TARGETS[name])
              return "static_cast<BasicObject*>(#{runtime_inst})"
            end
            if (runtime_class = FUSED_CLASS_TARGETS[name])
              return "(&#{runtime_class}_CLASS)"
            end
            return "k_#{name}()" if @user_constants.key?(name)
            "(&#{name}_CLASS)"
          end

          # The lexical scope chain rendered as part-arrays, innermost
          # first. `Parser::Base` (innermost) → `["Parser", "Base"]`.
          # Skips Object (the top-level scope).
          def scope_prefixes
            (@method_scope || []).reverse.filter_map { |s|
              next nil unless s.respond_to?(:full_name) && s.full_name
              fname = s.full_name.to_s
              next nil if fname == "Object"
              fname.split("::")
            }
          end

          # Walk a ConstantRead/ConstantPath/RootNamespaceNode chain and
          # return the flattened C++ identifier ("Foo_Bar_Baz" for
          # Foo::Bar::Baz). RootNamespaceNode (the `::Foo` form) is
          # treated as no-op — we don't have a separate root namespace
          # in box-first; everything's in `namespace Ruby`.
          def path_to_cpp_name(node)
            collect_path(node).join('_')
          end

          def path_to_display(node)
            collect_path(node).join('::')
          end

          def collect_path(node)
            case node
            when Ast::ConstantPath then collect_path(node.parent_node) + [node.name.to_s]
            when Ast::ConstantRead then [node.name.to_s]
            when Ast::RootNamespaceNode then []
            else [node.to_s]  # last-resort fallback
            end
          end

          # A class is instantiable as `new Ruby::X(...)` if it's emitted
          # — either from the user_classes registry or as a Universe-seeded
          # class.
          def instantiable_class?(name)
            @user_classes.key?(name) ||
              FUSED_CLASS_TARGETS.key?(name) ||
              Runtime::ALL_CLASSES.any? { |k| k.name == name.to_s }
          end

          # Resolve a Vm::ClassObject to its emitted flat name (the
          # eigenclass singleton's basename). Walks `full_name` and
          # tries each successive prefix against user_classes /
          # Universe. Returns nil if not found (caller raises).
          def class_object_to_flat(cls)
            fname = cls.full_name.to_s
            flat = fname.gsub("::", "_").to_sym
            return flat if instantiable_class?(flat)
            nil
          end
        end
      end
    end
  end
end
