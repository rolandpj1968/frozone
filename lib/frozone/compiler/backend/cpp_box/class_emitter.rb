# Box-first C++ backend — class emission.
#
# Generic: walks RubyClass instances + the program's call_surface,
# produces C++ class definitions + singleton instances + Kernel free
# functions. No per-class branching; behaviour is fully data-driven.
# Runtime classes (BasicObject, Integer, etc.) and user-defined classes
# go through the same path.
#
# Emission order (so all references resolve at C++ parse time):
#   1. Forward declarations (all classes + all free functions)
#   2. Class bodies (parent before child)
#   3. Singleton instances (after their classes are complete)
#   4. Free function bodies (after singletons exist)

require_relative 'runtime/universe'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class ClassEmitter
          # `classes` is the full list (Runtime::ALL_CLASSES + user
          # classes). `call_surface` is { [cpp_name, arity] => ruby_name }.
          # `kernel_fns` is the full list of free functions to emit
          # (Runtime::ALL_KERNEL_FNS + per-program user-constant accessors).
          # `intrinsics` is the list of low-level primitive ops compiled
          # Ruby methods dispatch into (currently empty; populated when
          # we source from core/4.0/).
          def self.write_runtime(emit, classes:, call_surface:,
                                const_surface: Set.new,
                                kernel_fns: Runtime::ALL_KERNEL_FNS,
                                intrinsics: Runtime::ALL_INTRINSICS)
            # Method-id assignment — every cpp_name in the call surface
            # gets a stable integer ID. Drives O(1) dispatch for send
            # and respond_to? (no string compare). Order = call_surface
            # iteration order = insertion order from collect_call_surface.
            method_ids = call_surface.keys.each_with_index.to_h
            # Set of cpp_names BasicObject's universal surface emits a
            # stub for — write_override_decl uses this to decide whether
            # an override on a derived class can carry the `override`
            # keyword. Methods unique to one class (e.g. Math.log2 when
            # no user code calls log2) have no parent stub and must drop
            # `override`.
            @call_surface_set = call_surface.keys.to_set
            # Natural-arity eligibility — populated when
            # FROZONE_NATURAL_ARGS=1; empty Hash otherwise so all
            # ineligible-path branches (universal-sig emission) stay
            # unchanged. Hash[Symbol, Int] of ruby_name → arity_req.
            @natural_arity_names = (emit.respond_to?(:natural_arity_names) ? emit.natural_arity_names : nil) || {}
            # Multi-arity defaults beachhead: names with one def shape
            # and optional positionals. Expand into per-arity overloads
            # (same C++ name, different param counts — C++ overload
            # resolution disambiguates). Universal slot drops; send /
            # mm_dispatch routes via the switch trampoline.
            @multi_arity_table = (emit.respond_to?(:multi_arity_table) ? emit.multi_arity_table : nil) || {}
            # Kw-bearing (UNSET) path: names whose def has at least one
            # kw param. Single slot signature: required pos → opt pos
            # (UNSET-able) → kws alphabetical (required slots required,
            # optional UNSET-able). Default-fill happens in callee body.
            @kw_unset_table = (emit.respond_to?(:kw_unset_table) ? emit.kw_unset_table : nil) || {}
            # Leaf-dispatch (FROZONE_LEAF_DISPATCH=1): names where the
            # def lives in exactly one defining class AND that class is
            # a leaf. BasicObject's universal-sig slot becomes a non-
            # virtual typeid gateway; the leaf's universal-sig override
            # is also non-virtual (name hiding gives free direct
            # dispatch from typed callers). Hash[ruby_name → cpp_leaf_name].
            raw_leaf = (emit.respond_to?(:leaf_dispatch_table) ? emit.leaf_dispatch_table : nil) || {}
            @leaf_dispatch_table = raw_leaf.each_with_object({}) do |(name, classes), h|
              h[name] = classes.map { |c| c.full_name.to_s.gsub("::", "_") }
            end
            # Constant surface — names referenced via dynamic-receiver
            # paths (`self.class::X`). Each gets a `c_X` virtual on
            # BasicObject + overrides on every eigenclass that has X.
            @const_surface = const_surface
            @const_surface_set = const_surface.map { |n| "c_#{n}" }.to_set
            # Inject `c_X → constant_missing` overrides on the Module
            # entry for every surface name. BasicObject's c_X default
            # is TypeError; Module's override flips it to NameError so
            # any module/class receiver gets correct semantics, while
            # non-module receivers (nil, Integer, …) keep TypeError.
            classes = inject_module_constant_overrides(classes, const_surface)
            # Class id assignment + IS_A LUT — drives is_a?/kind_of?.
            # Each class gets a unique id; LUT[i][j] = true iff class
            # i has class/module j in its ancestry chain (including
            # included/prepended modules).
            class_ids = classes.each_with_index.to_h { |k, i| [k.name, i] }
            is_a_lut = compute_is_a_lut(classes, class_ids, emit)
            responder_sets = compute_responder_sets(classes)
            classes = classes.map { |k| with_auto_overrides(k, responder_sets[k.name] || [], method_ids, class_ids[k.name]) }
            @class_ids = class_ids  # for write_class to access
            # Set of cpp class names that are LEAVES in the emitted
            # C++ hierarchy (no other class names them as parent).
            # write_class emits these as `final` — C++ devirtualises
            # typed-receiver virtual calls without LTO, orthogonal to
            # the leaf-dispatch typeid gateway (which targets
            # untyped-receiver BO* call sites).
            parent_set = classes.map(&:parent).compact.to_set
            @cpp_leaf_set = classes.map(&:name).reject { |n| parent_set.include?(n) }.to_set

            # Per-method override map → "no descendant overrides this
            # method" → emit method-level `final`. Lets the C++ compiler
            # devirtualise typed-receiver calls. Independent of (and
            # additive to) class-level `final` from @cpp_leaf_set.
            # Conservative grain: tracked by method NAME only (not per
            # overload signature) — false negatives (some never-overridden
            # overloads miss `final` if a sibling overload was overridden)
            # but no false positives (an actual override is never marked
            # final).
            @method_defs_by_name = Hash.new { |h, k| h[k] = Set.new }
            classes.each do |c|
              (c.overrides || {}).each_key { |name| @method_defs_by_name[name] << c.name }
            end
            @descendants_map = Hash.new { |h, k| h[k] = Set.new }
            parent_of = classes.to_h { |c| [c.name, c.parent] }
            classes.each do |c|
              ancestor = parent_of[c.name]
              while ancestor
                @descendants_map[ancestor] << c.name
                ancestor = parent_of[ancestor]
              end
            end

            # Two-pass: pre-render method bodies + send + kernel into a
            # buffer to populate emit.cpp.int_literals (Integer literal
            # interning), then emit __INT_LIT__ in the correct position
            # (after class struct decls so Integer is complete, before
            # method bodies so they can reference it), then replay the
            # buffered bodies. Static-state-init runs separately later
            # and may discover new literals — those would be missed by
            # this pass; collect them via a second sweep.
            body_buf = emit.capture do
              # Forward-declare the IS_A LUT + CLASS_BY_ID array so
              # inline class-body methods (e.g. Module#ancestors) can
              # reference them — the actual definitions come further
              # down in write_is_a_lut.
              # Routed to layouts header so per-class TUs see the decls.
              # N_CLASSES is `inline constexpr` for single-definition-
              # across-TUs (C++17).
              n_classes = class_ids.size
              # Route foundation declarations to :base. Per-class TUs
              # that #include "frozone_layouts.hpp" still see these
              # transitively because layouts.hpp opens with #include
              # "frozone_base.hpp".
              emit.with_stream(:base) do
                emit.line "inline constexpr int N_CLASSES = #{n_classes};"
                emit.line "extern const bool IS_A[N_CLASSES][N_CLASSES];"
                emit.line "extern BO* const CLASS_BY_ID[N_CLASSES];"
                emit.blank
              end
              # Per-class TU split. Each class's out-of-line method
              # definitions go to its own .cpp file —
              # frozone_<ClassName>.cpp. Each per-class TU includes
              # the layouts header, opens namespace Ruby, emits the
              # method bodies, closes namespace.
              #
              # Pay-off: Makefile's `g++ -j N -c *.cpp` parallelises;
              # editing one class touches one file (atomic write-if-
              # different is in FrozoneCompile.evaluate already);
              # incremental rebuilds become ~10-30 sec instead of
              # ~7 min (full rebuild today).
              classes.each do |k|
                stream_name = :"class_#{k.name}"
                emit.with_stream(stream_name) do
                  # Stage 3 Path 1 of the layouts.hpp split
                  # (project_layouts_split.md): precise per-class
                  # hpps are emitted BEFORE the layouts.hpp meta-
                  # include. Since each class hpp is #pragma once,
                  # the meta-include's transitive inclusion of the
                  # same hpps is a no-op; the precise list is what
                  # Stage 4 will use after layouts.hpp is dropped.
                  # Right now this just exercises the collection so
                  # we can audit the emitted include sets.
                  # frozone_all.hpp MUST be the FIRST include — gcc
                  # only activates the PCH (frozone_all.hpp.gch) when
                  # the TU starts with this exact include. The PCH
                  # captures base + post + layouts in cached form, so
                  # the entire universe loads in one step.
                  # Subsequent includes below are decorative no-ops
                  # (pragma once); they document Path 2's precise
                  # per-class dependency set so a future Stage can
                  # narrow the PCH scope without re-deriving.
                  emit.line %(#include "#{emit.base_name}_all.hpp")
                  emit.line %(#include "class/#{k.name}.hpp")
                  # Pair with the partner header in the non-self direction:
                  #  - Foo.cpp also includes Foo_eigenclass.hpp (for
                  #    `&Foo_CLASS` references in instance method bodies)
                  #  - Foo_eigenclass.cpp also includes Foo.hpp (for
                  #    `m_new()` returning Foo* etc. in class method bodies)
                  if k.name.to_s.end_with?("_eigenclass")
                    partner = k.name.to_s.sub(/_eigenclass\z/, "")
                    emit.line %(#include "class/#{partner}.hpp")
                  else
                    emit.line %(#include "class/#{k.name}_eigenclass.hpp")
                  end
                  # host_class_refs is keyed by flat-name Symbol;
                  # k.name from RubyClass may be String or Symbol —
                  # try both lookups.
                  # Union host_class_refs across the entire ancestor
                  # chain. Module-included methods (e.g. Enumerable's
                  # methods on Array) get walked under host=Enumerable
                  # but emitted into Array's .cpp via overlay; their
                  # refs need to flow into Array's include set too.
                  # ancestors_list traverses parent + included modules
                  # + prepends.
                  refs = Set.new
                  vm_for_k = (emit.user_classes[k.name.to_sym] rescue nil)
                  vm_for_k ||= (emit.top_level_scope&.constants_table || {})[k.name.to_sym]
                  if vm_for_k.respond_to?(:ancestors_list)
                    vm_for_k.ancestors_list.each do |anc|
                      anc_flat = (anc.respond_to?(:full_name) && anc.full_name ?
                                    anc.full_name.to_s.gsub("::", "_") :
                                    anc.name.to_s).to_sym
                      refs.merge(emit.host_class_refs[anc_flat] || Set.new)
                    end
                  end
                  # Also direct lookup by k.name (handles RubyClass
                  # entries that don't correspond to a Vm::ClassObject —
                  # eigenclasses, fused universe overlays).
                  refs.merge(emit.host_class_refs[k.name.to_sym] || Set.new)
                  refs.merge(emit.host_class_refs[k.name.to_s] || Set.new)
                  refs -= [k.name.to_sym, k.name.to_s]
                  # For each referenced class also include its
                  # eigenclass hpp — `Foo.new(...)` compiles to
                  # `(&Foo_CLASS)->m_new(...)`, where Foo_CLASS is of
                  # type Foo_eigenclass.
                  refs.to_a.sort.each do |r|
                    emit.line %(#include "class/#{r}.hpp")
                    emit.line %(#include "class/#{r}_eigenclass.hpp")
                  end
                  # intrinsics_helpers.hpp is needed unconditionally:
                  # bodies that call STUB intrinsics lower to
                  # `intrinsic_not_implemented("name")` from there,
                  # and the helpers header is small (~40 lines).
                  # Per-category headers also include it transitively
                  # when present.
                  emit.line %|#include "../../../runtime/intrinsics_helpers.hpp"|
                  # Per-TU intrinsic-category decls. Union across the
                  # ancestor chain (mirrors host_class_refs), so an
                  # Enumerable method overlaid onto Array gets the
                  # categories its body actually calls. Categories
                  # are recorded by collect_call_surface's IntrinsicCall
                  # branch via IntrinsicLowering.category_for. Each
                  # header is decl-only; bodies live in the matching
                  # cpp/runtime/intrinsics/X_intrinsics.cpp TU.
                  intr_cats = Set.new
                  if vm_for_k.respond_to?(:ancestors_list)
                    vm_for_k.ancestors_list.each do |anc|
                      anc_flat = (anc.respond_to?(:full_name) && anc.full_name ?
                                    anc.full_name.to_s.gsub("::", "_") :
                                    anc.name.to_s).to_sym
                      intr_cats.merge(emit.host_intrinsic_refs[anc_flat] || Set.new)
                    end
                  end
                  intr_cats.merge(emit.host_intrinsic_refs[k.name.to_sym] || Set.new)
                  intr_cats.to_a.sort.each do |cat|
                    emit.line %|#include "../../../runtime/intrinsics/#{cat}_intrinsics.hpp"|
                  end
                  emit.blank
                  emit.line "namespace Ruby {"
                  emit.blank
                  write_class_definitions(emit, k)
                  emit.blank
                  emit.line "}  // namespace Ruby"
                  emit.blank
                end
              end
              write_method_vt(emit, method_ids)
              write_natural_arity_default_bodies(emit, call_surface, classes.find { |k| k.name == "BasicObject" })
              write_trampoline_defs(emit, method_ids)
              write_send_body(emit, method_ids)
              write_is_a_lut(emit, class_ids, is_a_lut)
              write_method_missing_default(emit)
              write_constant_typeerror_body(emit)
              write_const_missing_default(emit)
              # Kernel fn + intrinsic bodies route to the :universe stream
              # → frozone_universe.cpp. Non-inline definitions, with
              # decls in layouts.hpp so other TUs can call them.
              emit.with_stream(:universe) do
                write_kernel_fn_bodies(emit, kernel_fns)
                write_intrinsic_bodies(emit, intrinsics)
              end
              yield if block_given?
            end

            # Method id table moved to base header (Stage 1 split).
            # The universe TU's intern() can read it via the layouts→base
            # include chain. C++17 inline variables → single definition
            # across all including TUs.
            emit.with_stream(:base) do
              write_method_id_table(emit, method_ids, call_surface)
            end
            # Forward decls go into frozone_base.hpp so any TU that
            # includes base (directly or via layouts.hpp) sees the
            # program's types and free function signatures. Emitter
            # wraps the :base stream with `namespace Ruby { ... }` —
            # write_forward_decls itself emits no namespace wrapper.
            emit.with_stream(:base) do
              write_forward_decls(emit, classes, kernel_fns, intrinsics)
            end
            emit.blank
            # Stage 2: each class struct goes to its own
            # `class/<Name>.hpp` (stream `:class_hpp_<Name>`). The
            # per-class hpp opens with `#include "../frozone_base.hpp"`
            # + `#include "<Parent>.hpp"` (transitive parent chain) +
            # its own `namespace Ruby { ... }` wrap. layouts.hpp then
            # `#include`s every class/<Name>.hpp in topo order, so any
            # TU that includes layouts.hpp gets the same world as before.
            # Per-class TUs continue to #include "frozone_layouts.hpp"
            # for backward compat (Stage 3 will narrow this).
            classes.each do |k|
              hpp_stream = :"class_hpp_#{k.name}"
              emit.with_stream(hpp_stream) do
                emit.line "#pragma once"
                emit.line %|#include "../#{emit.base_name}_base.hpp"|
                emit.line %|#include "#{k.parent}.hpp"| if k.parent
                emit.blank
                emit.line "namespace Ruby {"
                emit.blank
                write_class(emit, k, call_surface)
                emit.line "}  // namespace Ruby"
                emit.blank
              end
              emit.with_stream(:layouts) do
                emit.line %|#include "class/#{k.name}.hpp"|
              end
            end
            # Stage 3 Path 2: post-class content (int literals,
            # raw int arrays, intrinsics include, class var storage)
            # moves to frozone_post.hpp. Per-class TUs include
            # frozone_post.hpp instead of frozone_layouts.hpp, which
            # cuts per-TU header parse from 56k lines to ~15 universal
            # value type hpps + intrinsics. layouts.hpp closes by
            # `#include`ing post.hpp itself, so consumers that want
            # the world (frozone.cpp, universe.cpp, static.cpp) keep
            # working. write_post_open already opened the namespace.
            write_singletons(emit, classes)
            emit.blank
            # Integer literal optimisation lives in its own
            # frozone_int_literals.{hpp,cpp} pair:
            #   .hpp: extern decls + raw int64_t tables (pure data)
            #   .cpp: storage definitions (Integer ctor calls)
            # Per-TU sees only the extern decls; the constructor
            # calls are paid by one TU (frozone_int_literals.cpp).
            emit.with_stream(:int_literals_hpp) do
              emit.cpp.write_raw_int_array_decls(emit)
              emit.cpp.write_int_literal_decls(emit)
              emit.cpp.write_small_int_lut_decls(emit)
            end
            emit.with_stream(:int_literals_cpp) do
              emit.cpp.write_raw_int_array_defs(emit)
              emit.cpp.write_int_literal_defs(emit)
              emit.cpp.write_small_int_lut_defs(emit)
            end
            # Note: intrinsic-category includes are NOT emitted here.
            # Per-class TUs include only the categories their bodies
            # call (see :class_<Name> stream below); aggregator TUs
            # (frozone.cpp, universe, static) include the
            # `intrinsics.hpp` aggregator at file scope.
            emit.with_stream(:post) do
              write_class_var_storage(emit)
            end
            body_buf.each_line { |l| emit.line l.chomp }
          end

          # Emit one inline-global per `@@var` referenced during body
          # emission. Every cvar lives at namespace scope as
          # `cv_<HostFlat>__<name> = nil_instance()`; method bodies
          # reference the symbol directly. Inline storage means each
          # TU sees the same instance — single global per cvar.
          def self.write_class_var_storage(emit)
            cvars = emit.cpp.class_vars
            return if cvars.empty?
            emit.line "// Class variables (@@foo) — one inline global per (host, name)."
            cvars.each do |host, names|
              names.each do |n|
                emit.line "inline BO* cv_#{host}__#{n} = nil_instance();"
              end
            end
            emit.blank
          end

          # Compile-time name → method_id table — emitted as a flat
          # `std::pair<const char*, int>` array. intern() builds an
          # unordered_map from it lazily on first call. (A literal-
          # initialised `unordered_map<std::string, int>` with thousands
          # of entries blows up cc1plus into 16GB+ memory; the flat
          # array compiles in seconds because it's just static data.)
          def self.write_method_id_table(emit, method_ids, call_surface = {})
            emit.line "// AOT-assigned method ids — every method name in the program's"
            emit.line "// call surface gets a stable integer index. intern() builds an"
            emit.line "// unordered_map from this array on first call."
            emit.line "struct __NameId__ { const char* name; int id; };"
            # `inline` (C++17 inline variable) — single definition across
            # all TUs that include the layouts header. Required so that
            # the universe TU's intern() can read this table without
            # introducing ODR violations.
            emit.line "inline const __NameId__ METHOD_NAMES[] = {"
            emit.indented do
              method_ids.each do |cpp_name, id|
                # Prefer the actual Ruby name captured in call_surface
                # (cpp_name → ruby_name_string) over reverse-mangling the
                # cpp_name. The forward mapping `name= → mm_name_eq`
                # collides with literal `_set` endings (e.g. Ruby's
                # `module_const_set`), and reverse-mangling the cpp name
                # is ambiguous — call_surface remembers the original.
                ruby_name = (call_surface[cpp_name] || cpp_name_to_ruby(cpp_name)).to_s
                c = ruby_name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
                emit.line %({"#{c}", #{id}},  // id #{id}: #{cpp_name})
              end
            end
            emit.line "};"
            # `inline constexpr` (C++17 implicit-inline-on-constexpr is
            # ambiguous; explicit inline keeps the intent clear). Single
            # definition across all TUs that include the layouts header.
            emit.line "inline constexpr int METHOD_NAMES_COUNT = #{method_ids.size};"
            emit.blank
          end

          # Reverse Cpp.method_name to recover the Ruby name we'd see
          # at runtime as Symbol#name_.
          #
          #   `mm_X_q`    → `X?`   (predicate)
          #   `mm_X_bang` → `X!`   (bang)
          #   `mm_X_eq`   → `X=`   (setter)
          #   `m_X`       → `X`    (plain)
          #
          # The doubled-`mm_` prefix distinguishes special-suffix
          # methods from plain ones whose name happens to end in
          # `_q`/`_bang`/`_eq`. Operators (op_*) come from the
          # OP_NAMES inverse table. See Cpp.method_name for the
          # forward mapping and method_name_spec.rb for round-trip
          # tests.
          def self.cpp_name_to_ruby(cpp)
            inv = Cpp::OP_NAMES.invert
            return inv[cpp].to_s if inv.key?(cpp)
            s = cpp.to_s
            if s.start_with?('mm_')
              body = s[3..]
              return "#{body[0..-3]}?" if body.end_with?('_q')
              return "#{body[0..-6]}!" if body.end_with?('_bang')
              return "#{body[0..-4]}=" if body.end_with?('_eq')
              # `mm_` without recognised suffix — shouldn't happen
              # for any name produced by method_name. Return body
              # unchanged so callers can spot the anomaly.
              return body
            end
            return s[2..] if s.start_with?('m_')
            s
          end

          # Chain shadow slot `sm_<ruby_name>__from_<Origin>` (or its
          # op-name encoding) shares the head's ruby name for purposes
          # of natural-arity sig lookup — `super` from a natural-arity
          # head body calls the shadow slot with positional args, so
          # the shadow must use the same signature.
          def self.cpp_name_head_ruby(cpp)
            s = cpp.to_s
            return cpp_name_to_ruby(cpp) unless s.start_with?('sm_')
            # Strip "sm_" prefix and "__from_<Origin>" suffix.
            inner = s[3..]
            head = inner.split('__from_').first
            # Reverse op-name encoding for the head body.
            inv = Cpp::OP_NAMES.invert
            return inv["m_#{head}"].to_s if inv.key?("m_#{head}")
            if head.start_with?('mm_')
              body = head[3..]
              return "#{body[0..-3]}?" if body.end_with?('_q')
              return "#{body[0..-6]}!" if body.end_with?('_bang')
              return "#{body[0..-4]}=" if body.end_with?('_eq')
              return body
            end
            head
          end

          # Member-function-pointer table indexed by method_id. Each
          # entry points at the BasicObject:: declaration of the
          # method; calling through it does virtual dispatch on `this`,
          # so subclass overrides resolve correctly.
          def self.write_method_vt(emit, method_ids)
            emit.line "// Member-function-pointer vtable indexed by method_id."
            emit.line "// `(this->*METHOD_VT[id])(univ, args, kw, blk)` does virtual dispatch."
            emit.line "// For natural-arity and multi-arity names, the universal-sig"
            emit.line "// slot on BasicObject is the trampoline that switches into the"
            emit.line "// per-arity overload."
            emit.line "using __MethodFn__ = BO* (BasicObject::*)(UnivTag, Array*, Hash*, BO*);"
            emit.line "static const __MethodFn__ METHOD_VT[] = {"
            emit.indented do
              method_ids.each do |cpp, id|
                ruby = cpp_name_to_ruby(cpp)
                # Cast disambiguates the universal-sig overload when
                # natural-arity / multi-arity names have multiple
                # overloads on BasicObject sharing the same cpp name.
                emit.line "static_cast<__MethodFn__>(&BasicObject::#{cpp}),  // id #{id}: #{ruby}"
              end
            end
            emit.line "};"
            emit.line "static constexpr int METHOD_VT_SIZE = #{method_ids.size};"
            emit.blank
          end

          # Out-of-line bodies for BasicObject's natural-arity defaults.
          # The struct only declares — the body needs `new Array()`
          # which can't be inline while Array is still forward-
          # declared (Array inherits from BasicObject so its struct
          # comes after). Emit here, after class struct definitions
          # are complete and Array is fully visible. The fallthrough
          # path packs the named params back into an Array and
          # delegates to mm_dispatch — only exercised when no
          # subclass overrides the slot.
          def self.write_natural_arity_default_bodies(emit, call_surface, basic_object_klass)
            return if @natural_arity_names.empty? && @multi_arity_table.empty? && @kw_unset_table.empty? && @leaf_dispatch_table.empty?
            # Same skip set as write_universal_surface — names where
            # BasicObject already has a concrete out-of-line definition
            # (hand-coded or overlay override) would collide at link
            # time if we also emit a default body here.
            skip = (Runtime::BASIC_OBJECT.hand_coded_method_names || []).to_set
            (basic_object_klass&.overrides || {}).each_key { |cpp| skip << cpp }
            call_surface.each do |cpp_name, ruby_name|
              next if skip.include?(cpp_name)
              ruby_lit = ruby_name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
              if (sig = @natural_arity_names[ruby_name.to_sym])
                n = sig.arity_req
                pos_params = (0...n).map { |i| "BO* a#{i}" }
                kw_params = sig.required_kw_names.map { |kn| "BO* k_#{kn}" }
                block_param = sig.has_block ? ["Proc* block"] : []
                params = (pos_params + kw_params + block_param).join(', ')
                pack = (0...n).map { |i| "_args->data.push_back(a#{i});" }.join(' ')
                block_arg = sig.has_block ? "block" : "nil_instance()"
                # Pack kw params back into a Hash for mm_dispatch — the
                # fallthrough path doesn't know the natural-arity shape.
                if sig.required_kw_names.empty?
                  emit.line "BO* BasicObject::#{cpp_name}(#{params}) { Array* _args = new Array(); #{pack} return mm_dispatch(this, _args, &EMPTY_KWARGS, #{block_arg}, \"#{ruby_lit}\"); }"
                else
                  kw_pack = sig.required_kw_names.map { |kn| %|_kw->data[intern("#{kn}")] = k_#{kn};| }.join(' ')
                  emit.line "BO* BasicObject::#{cpp_name}(#{params}) { Array* _args = new Array(); #{pack} Hash* _kw = new Hash(); #{kw_pack} return mm_dispatch(this, _args, _kw, #{block_arg}, \"#{ruby_lit}\"); }"
                end
              elsif (family = @multi_arity_table[ruby_name.to_sym])
                family.arities.to_a.sort.each do |k|
                  params = (0...k).map { |i| "BO* a#{i}" }.join(', ')
                  pack = (0...k).map { |i| "_args->data.push_back(a#{i});" }.join(' ')
                  emit.line "BO* BasicObject::#{cpp_name}(#{params}) { Array* _args = new Array(); #{pack} return mm_dispatch(this, _args, &EMPTY_KWARGS, nullptr, \"#{ruby_lit}\"); }"
                end
              elsif (kw_sig = @kw_unset_table[ruby_name.to_sym])
                n_pos = kw_sig.arity_req + kw_sig.opt
                pos_params = (0...n_pos).map { |i| "BO* a#{i}" }
                kw_params = kw_sig.all_kw_names.map { |kn| "BO* k_#{kn}" }
                params = (pos_params + kw_params).join(', ')
                pack = (0...n_pos).map { |i| "_args->data.push_back(a#{i});" }.join(' ')
                kw_pack = kw_sig.all_kw_names.map { |kn| %|if (k_#{kn} != unset_instance()) _kw->data[intern("#{kn}")] = k_#{kn};| }.join(' ')
                emit.line "BO* BasicObject::#{cpp_name}(#{params}) { Array* _args = new Array(); #{pack} Hash* _kw = new Hash(); #{kw_pack} return mm_dispatch(this, _args, _kw, nullptr, \"#{ruby_lit}\"); }"
              end
            end
            emit.blank
            write_leaf_dispatch_gateway_bodies(emit)
          end

          # Out-of-line gateway body for each leaf-dispatch-eligible name.
          # Replaces the universal-sig virtual slot on BasicObject with a
          # non-virtual body that:
          #   - Compares typeid(*this) against each defining leaf class's
          #     typeid (K-way OR-chain for K defining leaves).
          #   - On match, downcasts and calls that leaf's universal-sig
          #     method directly (non-virtual, since both are non-virtual
          #     and same C++ name — name lookup at LeafClass scope picks
          #     the leaf's body).
          #   - On all-miss, falls through to mm_dispatch.
          # Out-of-line because typeid + downcast both need every leaf
          # class's struct to be complete.
          def self.write_leaf_dispatch_gateway_bodies(emit)
            return if @leaf_dispatch_table.empty?
            emit.line "// Leaf-dispatch gateways — non-virtual BO::m_X bodies that"
            emit.line "// typeid-check (K-way) and downcast to a defining leaf class."
            @leaf_dispatch_table.each do |ruby_name, leaf_cpps|
              cpp_name = Cpp.method_name(ruby_name)
              ruby_lit = ruby_name.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
              emit.line "BO* BasicObject::#{cpp_name}(UnivTag, Array* args, Hash* kwargs, BO* block) {"
              emit.indented do
                leaf_cpps.each do |leaf_cpp|
                  emit.line "if (typeid_eq_q<#{leaf_cpp}>()) {"
                  emit.indented do
                    emit.line "return static_cast<#{leaf_cpp}*>(this)->#{cpp_name}(univ, args, kwargs, block);"
                  end
                  emit.line "}"
                end
                emit.line "return mm_dispatch(this, args, kwargs, block, \"#{ruby_lit}\");"
              end
              emit.line "}"
            end
            emit.blank
          end

          # Emit one free-function trampoline per natural-arity-eligible
          # name. Each trampoline takes the universal-shape args
          # (Array, Hash, Block) — so send / mm_dispatch can call it
          # uniformly — and forwards to recv->m_<name>(a0, a1, ...) on
          # the natural-arity virtual slot. Validates arity, raises on
          # unexpected kwargs (eligible methods have no kw params).
          # Block is silently ignored per the v1 contract: eligibility
          # disqualifies block-bearing callers; sending with a block to
          # an eligible name reaches here, but the natural-arity body
          # never sees it (yield in body would LocalJumpError).
          # Universal-sig slot bodies for natural-arity and multi-arity
          # names. Each is the per-name trampoline — universal-sig
          # callers (send / mm_dispatch / splat call sites) land here
          # and the body routes into the right per-arity overload.
          # METHOD_VT[id] now points at this universal slot (no parallel
          # TRAMPOLINE_VT). Body is out-of-line because it accesses
          # Array's `data` field which isn't complete inside BasicObject.
          def self.write_trampoline_defs(emit, method_ids)
            return if @natural_arity_names.empty? && @multi_arity_table.empty? && @kw_unset_table.empty?
            method_ids.each_key do |cpp_name|
              ruby = cpp_name_to_ruby(cpp_name)
              sig = @natural_arity_names[ruby.to_sym]
              family = @multi_arity_table[ruby.to_sym]
              kw_sig = @kw_unset_table[ruby.to_sym]
              next unless sig || family || kw_sig
              if kw_sig
                min_arity = kw_sig.arity_req
                max_arity = kw_sig.arity_req + kw_sig.opt
                check_call = min_arity == max_arity ?
                  "check_arity_fixed(args->data.size(), #{min_arity});" :
                  "check_arity_range(args->data.size(), #{min_arity}, #{max_arity});"
                emit.line "BO* BasicObject::#{cpp_name}(UnivTag, Array* args, Hash* kwargs, BO* /*block*/) {"
                emit.indented do
                  emit.line check_call
                  # Extract kw values — required must be present, optional defaults to UNSET.
                  kw_sig.all_kw_names.each do |kn|
                    key_lit = kn.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
                    emit.line %|auto _it_#{kn} = kwargs->data.find(intern("#{key_lit}"));|
                    if kw_sig.kw_required?(kn)
                      emit.line %|if (_it_#{kn} == kwargs->data.end()) raise_missing_kw("#{key_lit}");|
                      emit.line "BO* _kv_#{kn} = _it_#{kn}->second;"
                    else
                      emit.line "BO* _kv_#{kn} = (_it_#{kn} == kwargs->data.end()) ? unset_instance() : _it_#{kn}->second;"
                    end
                  end
                  # Unknown-kw check: every key in kwargs must be in
                  # the expected set (required ∪ optional).
                  expected_set = kw_sig.all_kw_names.map { |kn| %|intern("#{kn.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}")| }.join(', ')
                  if expected_set.empty?
                    emit.line %|if (!kwargs->data.empty()) raise_unknown_kw(static_cast<Symbol*>(kwargs->data.begin()->first)->name_);|
                  else
                    emit.line %|for (auto& _kv : kwargs->data) { Symbol* _k = static_cast<Symbol*>(_kv.first); bool _ok = false; for (auto _e : {#{expected_set}}) { if (_k == _e) { _ok = true; break; } } if (!_ok) raise_unknown_kw(_k->name_); }|
                  end
                  # Positional slot values: required pos from args, optional pos from args or UNSET.
                  pos_slot_vals = (0...kw_sig.arity_req).map { |i| "args->data[#{i}]" }
                  opt_slot_vals = (0...kw_sig.opt).map do |i|
                    idx = kw_sig.arity_req + i
                    "((std::size_t)args->data.size() > #{idx}) ? args->data[#{idx}] : unset_instance()"
                  end
                  kw_slot_vals = kw_sig.all_kw_names.map { |kn| "_kv_#{kn}" }
                  all_vals = (pos_slot_vals + opt_slot_vals + kw_slot_vals).join(', ')
                  emit.line "return this->#{cpp_name}(#{all_vals});"
                end
                emit.line "}"
                next
              end
              if family
                arities = family.arities.to_a.sort
                min_arity = arities.first
                max_arity = arities.last
                emit.line "BO* BasicObject::#{cpp_name}(UnivTag, Array* args, Hash* kwargs, BO* /*block*/) {"
                emit.indented do
                  emit.line "if (kwargs != &EMPTY_KWARGS) args = fold_kwargs_into_args_tail(args, kwargs);"
                  emit.line "check_arity_range(args->data.size(), #{min_arity}, #{max_arity});"
                  emit.line "switch (args->data.size()) {"
                  emit.indented do
                    arities.each do |k|
                      args_call = (0...k).map { |i| "args->data[#{i}]" }.join(', ')
                      emit.line "case #{k}: return this->#{cpp_name}(#{args_call});"
                    end
                    emit.line "default: return nil_instance();  // unreachable: check_arity_range raises"
                  end
                  emit.line "}"
                end
                emit.line "}"
                next
              end
              n = sig.arity_req
              # Trampoline IS the universal-slot signature on
              # BasicObject — block stays `BO*` here.
              # has_block forwards convert at the seam (below).
              block_param_decl = sig.has_block ? "BO* block" : "BO* /*block*/"
              emit.line "BO* BasicObject::#{cpp_name}(UnivTag, Array* args, Hash* kwargs, #{block_param_decl}) {"
              emit.indented do
                if sig.required_kw_names.empty?
                  emit.line "if (kwargs != &EMPTY_KWARGS) args = fold_kwargs_into_args_tail(args, kwargs);"
                  emit.line "check_arity_fixed(args->data.size(), #{n});"
                  call_args = (0...n).map { |i| "args->data[#{i}]" }
                  # Normalise nil_instance() to nullptr so block_given?
                  # in the called slot is just `_block != nullptr`.
                  call_args << "block == nil_instance() ? nullptr : static_cast<Proc*>(block)" if sig.has_block
                  emit.line "return this->#{cpp_name}(#{call_args.join(', ')});"
                else
                  emit.line "check_arity_fixed(args->data.size(), #{n});"
                  sig.required_kw_names.each do |kn|
                    key_lit = kn.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
                    emit.line %|auto _it_#{kn} = kwargs->data.find(intern("#{key_lit}"));|
                    emit.line %|if (_it_#{kn} == kwargs->data.end()) raise_missing_kw("#{key_lit}");|
                  end
                  # Unknown-kw check: every key in kwargs must be a
                  # required kw for this name. Any extra raises
                  # ArgumentError matching MRI semantics.
                  expected_set = sig.required_kw_names.map { |kn| %|intern("#{kn.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')}")| }.join(', ')
                  emit.line %|for (auto& _kv : kwargs->data) { Symbol* _k = static_cast<Symbol*>(_kv.first); bool _ok = false; for (auto _e : {#{expected_set}}) { if (_k == _e) { _ok = true; break; } } if (!_ok) raise_unknown_kw(_k->name_); }|
                  call_args = (0...n).map { |i| "args->data[#{i}]" } +
                              sig.required_kw_names.map { |kn| "_it_#{kn}->second" }
                  # Normalise nil_instance() to nullptr so block_given?
                  # in the called slot is just `_block != nullptr`.
                  call_args << "block == nil_instance() ? nullptr : static_cast<Proc*>(block)" if sig.has_block
                  emit.line "return this->#{cpp_name}(#{call_args.join(', ')});"
                end
              end
              emit.line "}"
            end
            emit.blank
          end

          # Compute IS_A LUT: bool[N][N] where IS_A[i][j] = true iff
          # class/module i has class/module j in its ancestry. Captures
          # superclass chain + included/prepended modules.
          # Modules don't get emitted as structs but DO need ids in the
          # space — `is_a?(SomeMod)` checks against the module's id.
          # We materialise modules as lightweight singletons so the
          # `&Module_CLASS` reference at use sites resolves.
          def self.compute_is_a_lut(classes, class_ids, emit)
            top = emit.respond_to?(:top_level_scope) ? emit.send(:top_level_scope) : nil
            n = class_ids.size
            lut = Array.new(n) { Array.new(n, false) }
            # Each class is is_a itself.
            class_ids.each_value { |i| lut[i][i] = true }
            # Build a name → Vm::ClassObject/ModuleObject lookup for
            # ancestry walking. Cycle-detect via object_id (Frozone's
            # constants_table can be self-referential — Class is in
            # Object's table, Object is in Class's, etc.).
            vm_class = {}
            walked = Set.new
            walk_top = ->(scope, prefix) {
              return unless scope
              return if walked.include?(scope.object_id)
              walked << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                flat = prefix ? :"#{prefix}_#{name}" : name
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  vm_class[flat] = val
                  walk_top.call(val, flat)
                end
              end
            }
            walk_top.call(top, nil)
            # Walk each class's ancestry (Vm side) and set bits.
            klass_by_name = classes.each_with_object({}) { |k, h| h[k.name] = k }
            classes.each do |klass|
              i = class_ids[klass.name]
              # Eigenclass entries: skip the Vm-side walk. The Vm-side
              # only knows about the host class, and pulling its
              # ancestors here (e.g. `[Foo, Object, BasicObject]` into
              # Foo_eigenclass's row) would falsely set the
              # `Foo_eigenclass.is_a?(Foo)` bit. The C++ inheritance
              # chain (Foo_eigenclass : Class : Module : Object :
              # BasicObject) gives the correct ancestry — picked up
              # below via the parent-string walk.
              unless klass.name.end_with?("_eigenclass")
                vm = vm_class[klass.name.to_sym]
                if vm
                  (vm.ancestors_list rescue []).each do |a|
                    aid = class_ids[a.full_name.to_s.gsub("::", "_")]
                    lut[i][aid] = true if aid
                  end
                end
              end
              # Walk RubyClass.parent string chain. For non-eigenclass
              # entries this fills in universe-class hierarchy
              # (Class : Module : Object : BasicObject — Frozone's
              # Vm-level `Class.ancestors_list` is just `[Class]`).
              # For eigenclass entries it's the sole source of
              # ancestry — `Foo_eigenclass : Class` etc.
              p = klass.parent
              while p
                pid = class_ids[p]
                lut[i][pid] = true if pid
                p_klass = klass_by_name[p]
                p = p_klass&.parent
              end
            end
            lut
          end

          def self.write_is_a_lut(emit, class_ids, lut)
            n = class_ids.size
            emit.line "// Closed-world is_a? LUT — IS_A[receiver_class_id][target_class_id]"
            emit.line "// captures inheritance + module includes/prepends. Indexed by"
            emit.line "// the class_id assigned at AOT (see __class_id__()/instance_class_id_)."
            # N_CLASSES forward-declared earlier in body_buf; just define IS_A.
            emit.line "const bool IS_A[N_CLASSES][N_CLASSES] = {"
            emit.indented do
              # Inverse: id → name for comments
              id_to_name = class_ids.invert
              lut.each_with_index do |row, i|
                bits = row.map { |b| b ? "1" : "0" }.join(",")
                emit.line "{#{bits}},  // #{i}: #{id_to_name[i]}"
              end
            end
            emit.line "};"
            emit.blank
            # CLASS_BY_ID[i] returns the Class singleton with instance_class_id_ == i,
            # or nullptr if no class has that id. Used by Module#ancestors,
            # Module#descendants, and any other reflection that needs to
            # walk class IDs back to value objects.
            id_to_name = class_ids.invert
            emit.line "BO* const CLASS_BY_ID[N_CLASSES] = {"
            emit.indented do
              (0...n).each do |i|
                name = id_to_name[i]
                # Only the host classes (not eigenclasses) have a singleton
                # named "<Name>_CLASS" — for an eigenclass we'd want
                # &Class_CLASS, but Class is itself entry 3.
                if name && !name.to_s.end_with?("_eigenclass")
                  emit.line "&#{name}_CLASS,  // #{i}: #{name}"
                else
                  emit.line "nullptr,        // #{i}: #{name} (no singleton; use Class_CLASS)"
                end
              end
            end
            emit.line "};"
            emit.blank
            emit.line "BO* Object::mm_is_a_q(UnivTag, Array* args, Hash* kwargs, BO* block) {"
            emit.indented do
              emit.line "int my_id = this->__class_id__();"
              emit.line "if (my_id < 0) return false_instance();"
              emit.line "BO* target = args->data[0];"
              # m_class is auto-emitted on every class; eigenclass instances
              # all return &Class_CLASS (with_auto_overrides targets
              # Class_CLASS for any *_eigenclass class). One virtual call +
              # pointer compare beats walking RTTI via dynamic_cast<Class*>.
              emit.line "if (target->m_class(univ) != (&Class_CLASS)) return false_instance();"
              emit.line "auto* tc = static_cast<Class*>(target);"
              emit.line "int target_id = tc->instance_class_id_;"
              emit.line "if (target_id < 0 || target_id >= N_CLASSES) return false_instance();"
              emit.line "return boxed_bool(IS_A[my_id][target_id]);"
            end
            emit.line "}"
            emit.blank
            # NA-shape direct accessor — same LUT lookup as mm_is_a_q
            # but returns bool and skips the Array unpacking. Declared
            # on BasicObject so callers with BO* static type compile;
            # body works because __class_id__/m_class are virtual on BO
            # and the LUT/Class globals are visible at out-of-line
            # emission time. Used by rescue-clause emission and non-
            # leaf is_a?/kind_of? lowering.
            emit.line "bool BasicObject::mm_is_a_q_direct(BO* target) {"
            emit.indented do
              emit.line "int my_id = this->__class_id__();"
              emit.line "if (my_id < 0) return false;"
              emit.line "if (target->m_class(univ) != (&Class_CLASS)) return false;"
              emit.line "auto* tc = static_cast<Class*>(target);"
              emit.line "int target_id = tc->instance_class_id_;"
              emit.line "if (target_id < 0 || target_id >= N_CLASSES) return false;"
              emit.line "return IS_A[my_id][target_id];"
            end
            emit.line "}"
            emit.blank
          end

          # Add m_class + mm_respond_to_q + __class_id__ to every
          # class's overrides. m_class returns the eigenclass singleton
          # (`&Foo_CLASS`). mm_respond_to_q indexes a per-class static
          # bool array by Symbol::method_id_. __class_id__ returns the
          # AOT-assigned class_id used by the IS_A LUT.
          def self.with_auto_overrides(klass, responder_ruby_names, method_ids, class_id)
            # m_class and mm_respond_to_q are Kernel methods in MRI — they
            # don't exist on BasicObject. Leave BasicObject's stubs as
            # method_missing so a `class Foo < BasicObject` subclass
            # genuinely lacks them, matching MRI semantics.
            return klass if klass.name == "BasicObject"
            target =
              if klass.name.end_with?("_eigenclass")
                # The eigenclass's parent tells us if its instance is a
                # module or a class — `Module` parent → instance.class
                # is Module; otherwise Class.
                klass.parent == "Module" ? "Module_CLASS" : "Class_CLASS"
              else
                "#{klass.name}_CLASS"
              end
            overrides = (klass.overrides || {}).dup
            overrides["m_class"] ||= { params: [], body: "return (&#{target});" }
            overrides["mm_respond_to_q"] ||= {
              params: [],
              body: respond_to_body(klass.name, responder_ruby_names, method_ids),
            }
            # Auto-generate m_dup for non-eigenclass classes: shallow copy
            # via the C++ default copy constructor (memberwise copy of
            # all ivars + state). Force-override (no `||=`) because
            # module-flattening propagates Object#dup's
            # `intrinsic_object_dup(this)` body into every class's
            # overrides — that intrinsic only handles String/Array/Hash
            # and returns self_ for unknown classes, making
            # `@context.dup; @context.in_def = true` mutate both copies
            # and break Parser scope tracking. The typed copy here
            # always produces a fresh instance.
            #
            # Set gets a tweak: the memberwise copy leaves iv_hash as
            # a shared pointer between source and dup, so mutating one
            # Set's @hash (via add/delete) mutates the other. Deep-copy
            # iv_hash explicitly to give the dup independent storage.
            # Without this the whitequark Parser::StaticEnvironment
            # mis-classifies out-of-scope identifiers as local reads
            # (every block scope ends up sharing the surrounding scope's
            # variable set).
            # Eigenclasses don't get this — they're singletons.
            unless klass.name.end_with?("_eigenclass")
              body =
                if klass.name == "Set"
                  "auto* r = new Set(*this); r->iv_hash = r->iv_hash->m_dup(); return r;"
                else
                  "return new #{klass.name}(*this);"
                end
              overrides["m_dup"] = { params: [], body: body }
            end
            klass.dup.tap { |k| k.overrides = overrides }
          end

          def self.respond_to_body(class_name, responder_ruby_names, method_ids)
            n = method_ids.size
            # Build a bool array, true at indices that this class
            # responds to. Names not in the call surface (orphaned
            # responder names — shouldn't normally happen) are
            # silently ignored.
            bits = Array.new(n, false)
            responder_ruby_names.each do |ruby_name|
              cpp = Frozone::Compiler::Backend::CppBox::Cpp.method_name(ruby_name.to_sym)
              id = method_ids[cpp]
              bits[id] = true if id
            end
            arr_var = "__#{class_name}_responds__"
            bits_lit = bits.map { |b| b ? "1" : "0" }.join(",")
            <<~CPP.chomp
              static const bool #{arr_var}[] = {#{bits_lit}};
              if (args->data.empty()) return false_instance();
              int _id = static_cast<Symbol*>(args->data[0])->method_id_;
              return boxed_bool(_id >= 0 && _id < #{n} && #{arr_var}[_id]);
            CPP
          end

          # Compute per-class responder sets — own overrides + own
          # hand_coded_method_names + parent's set + the auto-emitted
          # m_class/mm_respond_to_q (which with_auto_overrides will add
          # only on Object and below). Walks the inheritance chain via
          # klass.parent (string), name-indexed. Returns Ruby names
          # (not cpp_names) for matching against Symbol#name_ at runtime.
          def self.compute_responder_sets(classes)
            registry = classes.each_with_object({}) { |k, h| h[k.name] = k }
            memo = {}
            walk = ->(klass) {
              return memo[klass.name] if memo.key?(klass.name)
              # Filter out non-method slots — c_X (constant lookup),
              # sm_X__from_<...> (super shadowing). They share the
              # overrides hash for emission but aren't user-callable
              # Ruby methods, so respond_to? must not return true for them.
              method_overrides = (klass.overrides || {}).keys.reject { |cpp| cpp.start_with?("c_", "sm_") }
              own = method_overrides.map { |cpp| cpp_name_to_ruby(cpp) }
              own += (klass.hand_coded_method_names || []).map { |cpp| cpp_name_to_ruby(cpp) }
              # m_class / mm_respond_to_q are auto-added by with_auto_overrides
              # on every class except BasicObject — pre-include them here so
              # responder_sets is correct (compute_responder_sets runs BEFORE
              # with_auto_overrides).
              own += %w[class respond_to?] unless klass.name == "BasicObject"
              parent_set = klass.parent && registry[klass.parent] ? walk.call(registry[klass.parent]) : []
              memo[klass.name] = (own + parent_set).uniq
            }
            classes.each_with_object({}) { |k, h| h[k.name] = walk.call(k) }
          end

          def self.write_forward_decls(emit, classes, kernel_fns, intrinsics)
            classes.each { |k| emit.line "struct #{k.name};" }
            emit.blank
            # Singleton extern declarations — class bodies emitted later
            # contain inline method definitions that reference other
            # classes' eigenclass singletons (`(&Module_CLASS)` etc.).
            # Forward `extern` lets `&NAME_CLASS` resolve before the
            # singleton's actual `inline X NAME_CLASS;` definition; the
            # forward-declared eigenclass type is enough to take its
            # address.
            classes.each do |k|
              next unless k.singleton
              emit.line "extern #{k.name} #{k.singleton};"
            end
            # Stable empty-args sentinel — every virtual decl uses
            # `Array* args = &EMPTY_ARGS` as its default, so 0-arity
            # calls (common via the universal protocol) elide to
            # `o->m_foo(univ)` instead of allocating a fresh empty Array
            # at every call site. extern here, definition lands in
            # write_singletons after Array's struct body is complete.
            emit.line "extern Array EMPTY_ARGS;"
            # Same pattern for kwargs: `Hash* kwargs = &EMPTY_KWARGS`
            # as the default keeps every BO*-bearing slot in
            # the universal protocol filled with a real object instead
            # of nullptr. Lets us drop nullptr branches throughout.
            emit.line "extern Hash EMPTY_KWARGS;"
            emit.blank
            # Non-inline declarations — bodies live in frozone_universe.cpp.
            # `inline` would force every TU including this header to also
            # see the body, but bodies stay in one TU. Without -flto we
            # lose cross-TU inlining; with -flto it's recovered.
            kernel_fns.each { |fn| emit.line "#{fn.signature};" }
            intrinsics.each { |fn| emit.line "#{fn.signature};" }
            emit.blank
            # UnivTag — empty-struct sentinel intended as the first
            # parameter of every universal-vtable slot:
            #   m_X(UnivTag, Array*, Hash*, BO*)
            # would fence the universal protocol from any NA per-arity
            # overload under C++ overload resolution. Declared here;
            # not yet threaded through decls or call sites (the full
            # migration is more than the "insert one token" framing
            # — every universal-call site across the Ruby emitter and
            # the cpp/runtime intrinsics headers needs `univ` prepended
            # in lockstep, ~120 lines total).
            emit.line "struct UnivTag {};"
            emit.line "inline constexpr UnivTag univ{};"
          end

          def self.write_intrinsic_bodies(emit, intrinsics)
            intrinsics.each do |fn|
              # Non-inline definition — declaration in layouts.hpp.
              emit.line "#{fn.signature} {"
              emit.indented { fn.body.each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
            end
          end

          def self.write_class(emit, klass, call_surface)
            inherits = klass.parent ? " : #{klass.parent}" : ""
            # `final` keyword goes BEFORE the base-class colon in C++:
            #   struct Foo final : Parent { ... };
            final = (@cpp_leaf_set && @cpp_leaf_set.include?(klass.name) && klass.name != "BasicObject") ? " final" : ""
            emit.line "struct #{klass.name}#{final}#{inherits} {"
            emit.indented do
              klass.members&.each { |m| emit.line m }
              klass.ivars&.each { |iv| emit.line iv }
              # Auto-emit __class_id__ override per class — simple int
              # return, no cross-class refs, safe inline.
              cid = @class_ids && @class_ids[klass.name]
              if cid && klass.name != "BasicObject"
                emit.line "int __class_id__() const override { return #{cid}; }"
              end
              if klass.name == "BasicObject"
                write_universal_surface(emit, call_surface, klass)
              end
              klass.overrides&.each { |name, spec| write_override_decl(emit, name, klass, spec) }
            end
            emit.line "};"
            emit.blank
          end

          # Out-of-line definitions for one class — every override body.
          # Emitted AFTER all classes and singletons are defined;
          # cross-references to other classes and `&Foo_CLASS` resolve
          # cleanly.
          def self.write_class_definitions(emit, klass)
            klass.overrides&.each { |name, spec| write_override_def(emit, klass.name, name, spec) }
          end

          # The universal m_* surface on BasicObject. One slot per unique
          # (cpp_name, arity) tuple — collisions on the same cpp_name
          # with different arities produce distinct C++ methods, all
          # named the same (Ruby method overloading isn't a thing, so
          # this *should* never happen — TODO: warn if it does).
          def self.write_universal_surface(emit, call_surface, basic_object_klass)
            return if call_surface.empty?
            # Skip:
            #  - hand-coded methods on BasicObject (declared in members:)
            #  - any cpp_name that BasicObject has via overlay/auto-overrides
            #    (would produce duplicate declarations, since overlays go
            #    through write_override_decl too)
            skip = (Runtime::BASIC_OBJECT.hand_coded_method_names || []).to_set
            (basic_object_klass.overrides || {}).each_key { |cpp| skip << cpp }
            emit.line "// Universal method surface — one slot per name. All Ruby methods take"
            emit.line "// (UnivTag, Array* args, Hash* kwargs, BO* block). Default body redirects to"
            emit.line "// m_method_missing on the receiver (which is itself a virtual, so user"
            emit.line "// `def method_missing` overrides participate)."
            call_surface.each do |cpp_name, ruby_name|
              next if skip.include?(cpp_name)
              ruby_lit = ruby_name.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
              if (sig = @natural_arity_names[ruby_name.to_sym])
                # Natural-arity: per-arity slot decl + universal-sig
                # slot decl (its body is the trampoline that switches
                # universal-sig callers into the natural-arity slot).
                # Universal slot drops its default-arg values to avoid
                # overload-resolution ambiguity with the 0-arg per-arity
                # slot — callers always pass explicit args/kwargs/block.
                # has_block sigs append a Proc* block trailing param;
                # the default `static_cast<Proc*>(nil_instance())`
                # lets block-less callers omit it. Default args live
                # only on the base (BasicObject) decl.
                pos_params = (0...sig.arity_req).map { |i| "BO* a#{i}" }
                kw_params = sig.required_kw_names.map { |kn| "BO* k_#{kn}" }
                block_param = sig.has_block ? ["Proc* block = nullptr"] : []
                params = (pos_params + kw_params + block_param).join(', ')
                emit.line %(virtual BO* #{cpp_name}(#{params});)
                emit.line %(virtual BO* #{cpp_name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());)
              elsif (family = @multi_arity_table[ruby_name.to_sym])
                family.arities.to_a.sort.each do |k|
                  params = (0...k).map { |i| "BO* a#{i}" }.join(', ')
                  emit.line %(virtual BO* #{cpp_name}(#{params});)
                end
                emit.line %(virtual BO* #{cpp_name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());)
              elsif (kw_sig = @kw_unset_table[ruby_name.to_sym])
                # Kw-bearing: single slot signature with required pos →
                # opt pos (UNSET-able) → kws alphabetical. Universal-sig
                # slot decl carries the per-name trampoline body.
                pos_params = (0...kw_sig.total_slots - kw_sig.all_kw_names.length).map { |i| "BO* a#{i}" }
                kw_params = kw_sig.all_kw_names.map { |kn| "BO* k_#{kn}" }
                params = (pos_params + kw_params).join(', ')
                emit.line %(virtual BO* #{cpp_name}(#{params});)
                emit.line %(virtual BO* #{cpp_name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());)
              elsif @leaf_dispatch_table[ruby_name.to_sym]
                # Leaf-dispatch: non-virtual gateway. Decl-only here;
                # body emits out-of-line via
                # write_leaf_dispatch_gateway_bodies after all leaf
                # class structs are complete.
                emit.line %(BO* #{cpp_name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());)
              else
                emit.line %(virtual BO* #{cpp_name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance()) { return mm_dispatch(this, args, kwargs, block, "#{ruby_lit}"); })
              end
            end
            # Constant-lookup surface — c_X() per dynamic-receiver
            # constant name. Default on BasicObject: TypeError (matches
            # MRI's `nil::FOO` raising "no class/module"). Module
            # overrides every slot to raise NameError (constant_missing)
            # — see write_module_constant_surface_overrides. Eigenclasses
            # then further override with `return <value>;` for the
            # constants they own.
            return if (@const_surface || []).empty?
            emit.blank
            emit.line "// Universal constant surface — `<expr>::CONST` (dynamic receiver)"
            emit.line "// dispatches through these slots. Static `Foo::CONST` keeps the"
            emit.line "// cheap k_<flat>() accessor and doesn't go through here."
            @const_surface.each do |name|
              cpp_name = "c_#{name}"
              next if skip.include?(cpp_name)
              # BasicObject default raises TypeError directly — `nil::FOO`
              # is unrecoverable. Module overrides each slot to instead
              # virtual-dispatch to m_const_missing (NameError, user-
              # overridable) — see inject_module_constant_overrides.
              emit.line %(virtual BO* #{cpp_name}() { return constant_typeerror("#{name}"); })
            end
            emit.blank
          end

          # Out-of-line m_send / m___send__ body. Single indirect call
          # through the method-vtable indexed by Symbol::method_id_.
          # Negative id (interned name not in call surface) →
          # method_missing.
          def self.write_send_body(emit, _method_ids)
            ["m_send", "m___send__"].each do |fn|
              emit.line "BO* Object::#{fn}(UnivTag, Array* args, Hash* kwargs, BO* block) {"
              emit.indented do
                emit.line %|if (args->data.empty()) { std::fprintf(stderr, "[box-first] send: no method name\\n"); std::abort(); }|
                emit.line "Symbol* _name = static_cast<Symbol*>(args->data[0]);"
                emit.line "int _id = _name->method_id_;"
                emit.line "Array* _rest = new Array();"
                emit.line "for (std::size_t _i = 1; _i < args->data.size(); _i++) _rest->data.push_back(args->data[_i]);"
                # Unknown id → m_method_missing path (mm_dispatch builds the
                # symbol-prepended args array and virtual-dispatches).
                emit.line "if (_id < 0 || _id >= METHOD_VT_SIZE) return mm_dispatch(this, _rest, kwargs, block, _name->name_);"
                # Single dispatch through METHOD_VT. For natural-arity
                # and multi-arity names, the universal-sig slot's body
                # is the trampoline that switches into the per-arity
                # overload — no parallel table needed.
                emit.line "return (this->*METHOD_VT[_id])(univ, _rest, kwargs, block);"
              end
              emit.line "}"
              emit.blank
            end
          end

          # Out-of-line method_missing — throws a Ruby NoMethodError. In
          # core/4.0/ many `rescue NoMethodError` blocks (e.g. IO#puts
          # probing for `arg.to_ary`) depend on this being a recoverable
          # exception rather than a process abort. The body builds a
          # message string + NoMethodError instance, both of which need
          # the universe to be complete — hence emitted alongside
          # is_a_lut / send_body, not inside BasicObject's struct body.
          # Mutate the Module entry to override every c_X surface slot
          # with a constant_missing call. Idempotent — won't clobber a
          # pre-existing override on Module.
          def self.inject_module_constant_overrides(classes, const_surface)
            return classes if const_surface.empty?
            classes.map do |k|
              next k unless k.name == "Module"
              merged = (k.overrides || {}).dup
              const_surface.each do |name|
                cpp_name = "c_#{name}"
                merged[cpp_name] ||= {
                  params: [],
                  body: %|return cm_dispatch(this, "#{name}");|,
                }
              end
              k.dup.tap { |kk| kk.overrides = merged }
            end
          end

          # constant_typeerror — raised when `c_X()` is called on a
          # non-Module receiver (e.g. `nil::X`, `42::FOO`). MRI raises
          # `TypeError: <Class>: is not a class/module`. Defined on
          # BasicObject as the default; Module overrides every c_X
          # slot to constant_missing instead.
          def self.write_constant_typeerror_body(emit)
            emit.line "BO* BasicObject::constant_typeerror(const char* /*const_name*/) {"
            emit.indented do
              emit.line %|if (std::getenv("FROZONE_BOX_TRACE")) {|
              emit.indented do
                emit.line %|std::fprintf(stderr, "constant_typeerror on %s — backtrace:\\n", ruby_class_name());|
                emit.line "void* bt[32];"
                emit.line "int n = backtrace(bt, 32);"
                emit.line "backtrace_symbols_fd(bt, n, 2);"
              end
              emit.line "}"
              emit.line "std::size_t clen = std::strlen(ruby_class_name());"
              emit.line %|static const char prefix[] = "";|
              emit.line %|static const char suffix[] = " is not a class/module";|
              emit.line "String* msg = new String();"
              emit.line "msg->bytes.reserve(clen + sizeof(suffix) - 1);"
              emit.line "msg->bytes.insert(msg->bytes.end(), ruby_class_name(), ruby_class_name() + clen);"
              emit.line "msg->bytes.insert(msg->bytes.end(), suffix, suffix + sizeof(suffix) - 1);"
              emit.line "Array* mm_args = new Array();"
              emit.line "mm_args->data.push_back(static_cast<BO*>(msg));"
              emit.line "throw static_cast<Exception*>((&TypeError_CLASS)->m_new(univ, mm_args));"
            end
            emit.line "}"
            emit.blank
          end

          # Default m_const_missing — Module#const_missing in MRI raises
          # NameError. User classes that `def const_missing` override
          # this via the normal vtable mechanism. args is `[Symbol]`.
          def self.write_const_missing_default(emit)
            emit.line "BO* BasicObject::m_const_missing(UnivTag, Array* args, Hash* /*kwargs*/, BO* /*block*/) {"
            emit.indented do
              emit.line "const char* const_name = args->data.empty() ? \"\" : static_cast<Symbol*>(args->data[0])->name_;"
              emit.line %|if (std::getenv("FROZONE_BOX_TRACE")) {|
              emit.indented do
                emit.line %|std::fprintf(stderr, "const_missing: %s on %s — backtrace:\\n", const_name, ruby_class_name());|
                emit.line "void* bt[32];"
                emit.line "int n = backtrace(bt, 32);"
                emit.line "backtrace_symbols_fd(bt, n, 2);"
              end
              emit.line "}"
              emit.line "std::size_t nlen = std::strlen(const_name);"
              emit.line "std::size_t clen = std::strlen(ruby_class_name());"
              emit.line %|static const char prefix[] = "uninitialized constant ";|
              emit.line %|static const char mid[] = "::";|
              emit.line "String* msg = new String();"
              emit.line "msg->bytes.reserve(sizeof(prefix) - 1 + clen + sizeof(mid) - 1 + nlen);"
              emit.line "msg->bytes.insert(msg->bytes.end(), prefix, prefix + sizeof(prefix) - 1);"
              emit.line "msg->bytes.insert(msg->bytes.end(), ruby_class_name(), ruby_class_name() + clen);"
              emit.line "msg->bytes.insert(msg->bytes.end(), mid, mid + sizeof(mid) - 1);"
              emit.line "msg->bytes.insert(msg->bytes.end(), const_name, const_name + nlen);"
              emit.line "Array* mm_args = new Array();"
              emit.line "mm_args->data.push_back(static_cast<BO*>(msg));"
              emit.line "throw static_cast<Exception*>((&NameError_CLASS)->m_new(univ, mm_args));"
            end
            emit.line "}"
            emit.blank
          end

          # Default m_method_missing — BasicObject#method_missing in MRI
          # raises NoMethodError. User classes that `def method_missing`
          # override this via the normal vtable mechanism. args is
          # `[Symbol.method_name, *original_args]` (mm_dispatch builds it).
          def self.write_method_missing_default(emit)
            emit.line "BO* BasicObject::m_method_missing(UnivTag, Array* args, Hash* /*kwargs*/, BO* /*block*/) {"
            emit.indented do
              emit.line "const char* method_name = args->data.empty() ? \"\" : static_cast<Symbol*>(args->data[0])->name_;"
              # FROZONE_BOX_TRACE=1 dumps a libc backtrace at the throw
              # site so we can map back to a source line via addr2line.
              # Off by default — would be noisy on every legitimate
              # rescue NoMethodError.
              emit.line %|if (std::getenv("FROZONE_BOX_TRACE")) {|
              emit.indented do
                emit.line %|std::fprintf(stderr, "method_missing: %s on %s — backtrace:\\n", method_name, ruby_class_name());|
                emit.line "void* bt[32];"
                emit.line "int n = backtrace(bt, 32);"
                emit.line "backtrace_symbols_fd(bt, n, 2);"
              end
              emit.line "}"
              emit.line "std::size_t nlen = std::strlen(method_name);"
              emit.line "std::size_t clen = std::strlen(ruby_class_name());"
              emit.line %|static const char prefix[] = "undefined method '";|
              emit.line %|static const char mid[] = "' for an instance of ";|
              emit.line "String* msg = new String();"
              emit.line "msg->bytes.reserve(sizeof(prefix) - 1 + nlen + sizeof(mid) - 1 + clen);"
              emit.line "msg->bytes.insert(msg->bytes.end(), prefix, prefix + sizeof(prefix) - 1);"
              emit.line "msg->bytes.insert(msg->bytes.end(), method_name, method_name + nlen);"
              emit.line "msg->bytes.insert(msg->bytes.end(), mid, mid + sizeof(mid) - 1);"
              emit.line "msg->bytes.insert(msg->bytes.end(), ruby_class_name(), ruby_class_name() + clen);"
              emit.line "Array* mm_args = new Array();"
              emit.line "mm_args->data.push_back(static_cast<BO*>(msg));"
              emit.line "throw static_cast<Exception*>((&NoMethodError_CLASS)->m_new(univ, mm_args));"
            end
            emit.line "}"
            emit.blank
          end

          # Universal override declaration: just the signature, terminated
          # with `;`. Default args (`= nullptr`) live here. `override` is
          # emitted only when the method exists on a parent — BasicObject
          # itself has no parent, and methods unique to a runtime
          # eigenclass (e.g. Math.log2 when no user code calls log2) lack
          # a parent stub so can't carry `override` either.
          # True if method `name` on `klass_name` has no descendant
          # override anywhere in the hierarchy — eligible for
          # method-level `final`. Skips BasicObject (its slots are the
          # universal-surface dispatch points, override is the whole
          # point) and leaf classes (already `struct X final`, so
          # method-level final would be redundant).
          def self.method_final?(klass_name, name)
            return false if klass_name == "BasicObject"
            return false if @cpp_leaf_set&.include?(klass_name)
            return false unless @descendants_map && @method_defs_by_name
            defs = @method_defs_by_name[name]
            !@descendants_map[klass_name].any? { |d| defs.include?(d) }
          end

          def self.write_override_decl(emit, name, klass, spec = nil)
            if name.start_with?("c_")
              # Constant-lookup slot — empty arg list. `override` only
              # if the slot exists on BasicObject (i.e. is in the
              # constant surface).
              override_kw = (klass.name == "BasicObject" || !@const_surface_set&.include?(name)) ? "" : " override"
              emit.line "virtual BO* #{name}()#{override_kw};"
              return
            end
            override_kw = (klass.name == "BasicObject" || !@call_surface_set&.include?(name)) ? "" : " override"
            final_kw = method_final?(klass.name, name) ? " final" : ""
            ruby_name = cpp_name_head_ruby(name).to_sym
            # `using` un-hides BasicObject's universal-sig overload so
            # `this->m_foo(args, kwargs, block)` calls inside the class
            # body still resolve. Only emit for slots that actually
            # exist on BasicObject (the head slot, not sm_X__from_Y
            # chain shadows which live only on the defining class).
            emit_using = !name.start_with?("sm_") && klass.name != "BasicObject"
            if (sig = @natural_arity_names[ruby_name])
              emit.line "using BasicObject::#{name};" if emit_using
              pos_params = (0...sig.arity_req).map { |i| "BO* a#{i}" }
              kw_params = sig.required_kw_names.map { |kn| "BO* k_#{kn}" }
              # has_block sigs carry a trailing Proc* block param.
              # Default = static_cast<Proc*>(nil_instance()) so callers
              # can omit it. Default args are evaluated against the
              # static type of the call expression; emitting the
              # default on every decl (base + overrides) keeps call
              # sites working through any pointer type.
              block_param = sig.has_block ? ["Proc* block = nullptr"] : []
              all_params = pos_params + kw_params + block_param
              emit.line "virtual BO* #{name}(#{all_params.join(', ')})#{override_kw}#{final_kw};"
              if klass.name == "BasicObject"
                emit.line "virtual BO* #{name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());"
              end
            elsif (family = @multi_arity_table[ruby_name])
              emit.line "using BasicObject::#{name};" if emit_using
              family.arities.to_a.sort.each do |k|
                params = (0...k).map { |i| "BO* a#{i}" }.join(', ')
                emit.line "virtual BO* #{name}(#{params})#{override_kw}#{final_kw};"
              end
              # Per-class universal-sig override (class-specific arity
              # range) when spec carries a universal_entry, or always
              # on BasicObject (the family-wide trampoline body).
              # Chain shadow slots (sm_X__from_Y) skip the override —
              # they're called from super and have no parent slot.
              if klass.name == "BasicObject" || (spec && spec[:universal_entry] && !name.start_with?("sm_"))
                ovk = klass.name == "BasicObject" ? "" : " override"
                emit.line "virtual BO* #{name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance())#{ovk}#{final_kw};"
              end
            elsif (kw_sig = @kw_unset_table[ruby_name])
              emit.line "using BasicObject::#{name};" if emit_using
              n_pos = kw_sig.arity_req + kw_sig.opt
              pos_params = (0...n_pos).map { |i| "BO* a#{i}" }
              kw_params = kw_sig.all_kw_names.map { |kn| "BO* k_#{kn}" }
              emit.line "virtual BO* #{name}(#{(pos_params + kw_params).join(', ')})#{override_kw}#{final_kw};"
              if klass.name == "BasicObject"
                emit.line "virtual BO* #{name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());"
              end
            elsif @leaf_dispatch_table[ruby_name] && klass.name != "BasicObject"
              # Leaf-dispatched name: BO's slot is a non-virtual gateway
              # (typeid-check + downcast); leaf body must be non-virtual
              # too, with the same C++ name. Name hiding gives free direct
              # dispatch from typed callers (no `using` needed).
              emit.line "BO* #{name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance());"
            else
              emit.line "virtual BO* #{name}(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance())#{override_kw}#{final_kw};"
            end
          end

          # Out-of-line override definition. spec[:params] is a list of
          # "BO* <name>" strings — the body wants those
          # extracted from args. Universal protocol auto-generates the
          # unpack lines (`BO* <name> = array_at(args, i);`).
          # User-class overrides pass empty params (their bodies have
          # their own unpacking via MethodEmitter.unpack_params).
          def self.write_override_def(emit, class_name, name, spec)
            if name.start_with?("c_")
              # Constant-lookup slot — empty arg list, body is a `return
              # <value>;` line. Non-inline now (per-class TU split) —
              # bodies are unique defs in their TU, not duplicated
              # inline definitions in every TU's vtable reference.
              emit.line "BO* #{class_name}::#{name}() {"
              emit.indented do
                spec[:body].each_line { |l| emit.line l.chomp }
              end
              emit.line "}"
              emit.blank
              return
            end
            # Hand-coded / overlay override on a multi-arity name —
            # spec is single-form (params + body). Wrap as the per-arity
            # slot at params.length (the "real" body), and emit wrong-
            # args stubs at the other family arities so out-of-arity
            # calls raise ArgumentError instead of falling to
            # method_missing.
            ruby_name_head = cpp_name_head_ruby(name).to_sym
            if (family = @multi_arity_table[ruby_name_head]) && spec[:multi_arity].nil? && spec[:kw_unset].nil?
              spec_param_decls = spec[:params] || []
              spec_arity = spec_param_decls.length
              spec_param_names = spec_param_decls.map { |decl| decl.split(/\s+/).last.delete_prefix('*') }
              family.arities.to_a.sort.each do |k|
                params = (0...k).map { |i| "BO* _arg#{i}" }.join(', ')
                if k == spec_arity
                  emit.line "BO* #{class_name}::#{name}(#{params}) {"
                  emit.indented do
                    spec_param_names.each_with_index do |pname, i|
                      emit.line "BO* #{pname} = _arg#{i};"
                    end
                    spec[:body].each_line { |l| emit.line l.chomp }
                  end
                  emit.line "}"
                else
                  emit.line "BO* #{class_name}::#{name}(#{params}) {"
                  emit.indented do
                    emit.line "check_arity_fixed(#{k}, #{spec_arity});"
                    emit.line "return nil_instance();"
                  end
                  emit.line "}"
                end
                emit.blank
              end
              return
            end
            # Multi-arity beachhead: spec carries N (params, body) pairs,
            # one per servable arity. Emit one out-of-line definition per
            # entry — they all share the cpp_name and dispatch by overload
            # resolution at call sites.
            if (entries = spec[:multi_arity])
              entries.each do |entry|
                params = entry[:params] || []
                emit.line "BO* #{class_name}::#{name}(#{params.join(', ')}) {"
                emit.indented do
                  entry[:body].each_line { |l| emit.line l.chomp }
                end
                emit.line "}"
                emit.blank
              end
              # Per-class universal-sig override (class-specific arity
              # error). Emitted when this class's arity range is
              # narrower than the family's — body re-runs the check
              # with class arities so the error message matches MRI.
              # Skip for chain shadows (sm_X__from_Y) — they don't
              # exist on a parent class to override.
              if (univ = spec[:universal_entry]) && !name.start_with?("sm_")
                params = univ[:params] || []
                emit.line "BO* #{class_name}::#{name}(#{params.join(', ')}) {"
                emit.indented { univ[:body].each_line { |l| emit.line l.chomp } }
                emit.line "}"
                emit.blank
              end
              return
            end
            # Kw-unset out-of-line def — spec[:params] already lists the
            # full slot signature (required pos → opt pos → all kws);
            # body is the default-fill prologue + method body.
            if spec[:kw_unset]
              params = spec[:params] || []
              emit.line "BO* #{class_name}::#{name}(#{params.join(', ')}) {"
              emit.indented { spec[:body].each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
              return
            end
            if (sig = @natural_arity_names[cpp_name_head_ruby(name).to_sym])
              # Natural-arity override out-of-line def. The spec's
              # params list names the BODY-visible locals; for
              # positional-only natural-arity (no kw), this is the
              # full signature. For kw-bearing natural-arity, the
              # spec body uses the kw names directly — we append
              # `_kw_<name>` slots after the positional ones and
              # treat the spec as if it had already declared them.
              spec_param_names = (spec[:params] || []).map { |decl| decl.split(/\s+/).last.delete_prefix('*') }
              if spec_param_names.length != sig.arity_req
                # Spec doesn't match natural-arity contract — fall back
                # to universal sig so the def stays consistent with
                # something. Shouldn't happen if eligibility is sound.
                emit.line "BO* #{class_name}::#{name}(UnivTag, Array* args, Hash* kwargs, BO* block) {"
                emit.indented do
                  (spec[:params] || []).each_with_index do |param_decl, i|
                    param_name = param_decl.split(/\s+/).last.delete_prefix('*')
                    emit.line "BO* #{param_name} = array_at(args, #{i});"
                  end
                  spec[:body].each_line { |l| emit.line l.chomp }
                end
                emit.line "}"
                emit.blank
                return
              end
              pos_params = spec_param_names.map { |n| "BO* #{n}" }
              kw_params = sig.required_kw_names.map { |kn| "BO* _kw_#{kn}" }
              block_param = sig.has_block ? ["Proc* block"] : []
              emit.line "BO* #{class_name}::#{name}(#{(pos_params + kw_params + block_param).join(', ')}) {"
              emit.indented do
                # If the spec body references kw param names directly,
                # bind each to its `_kw_<name>` incoming slot.
                sig.required_kw_names.each do |kn|
                  emit.line "BO* #{kn} = _kw_#{kn};"
                end
                emit.line "Proc* _block = block;" if sig.has_block
                spec[:body].each_line { |l| emit.line l.chomp }
              end
              emit.line "}"
              emit.blank
              return
            end
            # Spec without :kw_unset flag but slot decl is kw_unset
            # (Struct attr accessors, auto-generated bodies for slots
            # whose name aggregates to kw_unset from defs elsewhere).
            # Decl was emitted via @kw_unset_table at line 1280; def
            # must match — unused kw params just sit there.
            if (kw_sig = @kw_unset_table[cpp_name_head_ruby(name).to_sym])
              n_pos = kw_sig.arity_req + kw_sig.opt
              pos_params = (spec[:params] || []).each_with_index.map do |decl, i|
                "BO* #{decl.split(/\s+/).last.delete_prefix('*')}"
              end
              pad_n = n_pos - pos_params.length
              pad = (0...pad_n).map { |i| "BO* _arg_unused#{pos_params.length + i}" }
              kw_params = kw_sig.all_kw_names.map { |kn| "BO* _kw_unused_#{kn}" }
              emit.line "BO* #{class_name}::#{name}(#{(pos_params + pad + kw_params).join(', ')}) {"
              emit.indented { spec[:body].each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
              return
            end
            emit.line "BO* #{class_name}::#{name}(UnivTag, Array* args, Hash* kwargs, BO* block) {"
            emit.indented do
              (spec[:params] || []).each_with_index do |param_decl, i|
                param_name = param_decl.split(/\s+/).last.delete_prefix('*')
                emit.line "BO* #{param_name} = array_at(args, #{i});"
              end
              spec[:body].each_line { |l| emit.line l.chomp }
            end
            emit.line "}"
            emit.blank
          end

          def self.write_singletons(emit, classes)
            classes.each do |k|
              next unless k.singleton
              emit.line "inline #{k.name} #{k.singleton};"
            end
            # Definition for the EMPTY_ARGS extern declared above.
            # Array struct is complete by this point; the singleton
            # backs every default `Array* args = &EMPTY_ARGS` parameter.
            emit.line "inline Array EMPTY_ARGS;"
            emit.line "inline Hash EMPTY_KWARGS;"
          end

          def self.write_kernel_fn_bodies(emit, kernel_fns)
            kernel_fns.each do |fn|
              # Non-inline definition — declaration in layouts.hpp.
              emit.line "#{fn.signature} {"
              emit.indented { fn.body.each_line { |l| emit.line l.chomp } }
              emit.line "}"
              emit.blank
            end
          end
        end
      end
    end
  end
end
