# Naming for emitted C++ artifacts.
#
# Dependency-free (no VM stack requires) so early consumers like
# runtime/universe.rb can reach it during class-body evaluation
# before Reachability is loaded. Reachability re-exports `flatten`
# so existing `Reachability.flatten(...)` callers keep working.
#
# Two levels of API:
#
#   Backend::CppBox::EIG_SUFFIX     — bare constant (legacy)
#   Backend::CppBox::flatten(path)  — Ruby-name → C++-identifier
#   Backend::CppBox::k_call(path)   — value-constant accessor call
#   Backend::CppBox::klass_ptr(path)/klass_ptr_ref — class-CLASS singleton
#   Backend::CppBox::eig_struct(path) — eigenclass struct identifier
#
# Rule: any Ruby source that constructs a C++ output string
# referencing a Ruby-space name (`k_Foo_Bar()`, `&Foo_Bar_CLASS`,
# `Foo_Bar_eig`) MUST go through one of these helpers. Hand-writing
# the encoded form silently misresolves when the escape rule
# changes or the Ruby name has an underscore. Grep-linted by
# spec/frozone/compiler/backend/cpp_box/naming_hygiene_spec.rb.

module Frozone
  module Compiler
    module Backend
      module CppBox
        # Suffix appended to a class's flat name to form its eigenclass
        # struct's C++ identifier. Nod to the Eiger's Nordwand — pick
        # any 3-letter thing you like; it just has to be unique across
        # every non-eigenclass name in the closed world (task #216
        # renamed from `_eigenclass` for compactness).
        EIG_SUFFIX = "_eig"

        module_function

        # Ruby class/constant path → C++ identifier. Escapes source `_`
        # to `__` FIRST (so `Foo_Bar` bare vs `Foo::Bar` nested don't
        # collide) then collapses `::` → `_` (task #215). The parity
        # of underscore runs in the encoded form recovers which came
        # from `::` boundaries vs source underscores — the encoding is
        # a bijection.
        def flatten(path) = path.to_s.gsub("_", "__").gsub("::", "_")

        # C++ expression for a value-constant accessor CALL — e.g.
        # `k_call("Encoding::UTF_8")` → `"k_Encoding_UTF__8()"`. Used
        # for consts stored in the C++ globals table.
        def k_call(path) = "k_#{flatten(path)}()"

        # C++ address-of expression for a class-CLASS singleton pointer.
        # `klass_ptr_ref("Rational")` → `"(&Rational_CLASS)"`. This is
        # the form that goes at the RHS of an assignment / call. For
        # the bare identifier (no `&`, no parens) use `klass_ptr_name`.
        def klass_ptr_ref(path) = "(&#{klass_ptr_name(path)})"

        # Bare C++ identifier for the class-CLASS singleton — e.g.
        # `klass_ptr_name("Module")` → `"Module_CLASS"`. Use this when
        # interpolating into a larger expression that already provides
        # the `&`/parens (extern decls, per-class name tables).
        def klass_ptr_name(path) = "#{flatten(path)}_CLASS"

        # C++ identifier for the eigenclass struct — e.g.
        # `eig_struct("Frozone::Vm::ModuleObject")` →
        # `"Frozone_Vm_ModuleObject_eig"`.
        def eig_struct(path) = "#{flatten(path)}#{EIG_SUFFIX}"
      end
    end
  end
end
