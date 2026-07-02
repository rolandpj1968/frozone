# Box-first C++ backend — orchestrator.
#
# Parallel to the mainline `Frozone::Compiler::CppEmitter`. Where mainline
# specialises eagerly and falls back to box on TI failure, this emitter
# inverts the polarity: every value is `Ruby::X*` deriving from
# `Ruby::BasicObject`, dispatched via C++ virtual methods. TI-driven
# unboxing is the optimisation pass — added later, on top of an
# always-correct baseline.
#
# Invoked by Frozone.compile! (see ast/frozone_compile.rb).
#
# See memory/project_radical_box_first.md for the pinned plan.
#
# Vocab note: methods that mutate the buffer are `write_*`. Pure
# functions producing cpp strings live on `Cpp` (held as `emit.cpp`).

require_relative 'cpp'
require_relative 'intrinsic_lowering'
require_relative 'snapshot'
require_relative 'class_emitter'
require_relative 'method_emitter'
require_relative 'expr_emitter'
require_relative 'method_shape_survey'
require_relative 'visibility_survey'
require_relative '../../module_flattening'
require_relative '../../reachability'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Emitter
          attr_reader :cpp, :top_level_scope, :user_classes, :user_constants, :natural_arity_names, :multi_arity_table, :kw_unset_table, :leaf_dispatch_table, :visibility_survey, :non_escaping_block_names
          # When true, emission errors inside method bodies re-raise
          # under FROZONE_BOX_HARD_FAIL=1 instead of graceful-skipping.
          # Toggled true while emitting user-class bodies + the
          # execute_block (program path); left false while overlaying
          # universe-class methods (a method like `Object#instance_exec`
          # is reachable-by-definition but typically never called, and
          # we don't want to abort the build for it).
          attr_accessor :strict_emit

          attr_reader :base_name

          def initialize(base_name: "frozone")
            # `base_name` is the per-binary file prefix. e.g. fib.rb gens
            # `fib_all.hpp`, `fib_base.hpp`, `fib.cpp`. Defaults to
            # "frozone" so frozone_box's gen layout is unchanged.
            # Threaded into every `#include "frozone_*.hpp"` literal so
            # the include strings track the actual filenames the writer
            # emits to disk.
            @base_name = base_name
            # Multi-stream output. Each stream becomes one .cpp/.hpp file
            # in the output directory.
            # - `:layouts` is the shared header (frozone_layouts.hpp) —
            #   gradually accumulates struct decls, extern globals,
            #   inline function signatures. Built in steps; for now it
            #   has just `#pragma once` + box_first.hpp + an empty
            #   namespace Ruby. Future steps move forward decls, then
            #   struct definitions, then extern globals into it.
            # - `:default` is frozone.cpp — the bulk of the gen (forward
            #   decls still here for now, class defs, method bodies,
            #   static state init). #includes frozone_layouts.hpp so it
            #   sees whatever the header has.
            # - `:main` is a small trampoline that wraps the
            #   `frozone_main_impl` defined in :default.
            # Stage 1 of the layouts.hpp split (project_layouts_split.md):
            # `:base` carries the universal scaffolding (forward decls,
            # METHOD_NAMES, IS_A LUT decls, free-function decls, class var
            # storage) that every per-class TU needs to see before per-class
            # struct definitions. layouts.hpp opens with #include
            # "frozone_base.hpp" then defines the class structs.
            # Stage 3 Path 2 (project_layouts_split.md):
            # `:post` carries the post-class content (int literals,
            # raw int arrays, intrinsics impl include, class-var
            # storage) that needs class struct visibility for
            # universal value types.
            # `:all_hpp` is the PCH cache root — a thin meta-header
            # that #includes base + post + layouts. Per-class TUs
            # start with `#include "frozone_all.hpp"` so gcc loads
            # the .gch instantly. Decouples the PCH input from the
            # actual include strategy: when layouts.hpp eventually
            # goes away, we just edit frozone_all.hpp to stop
            # including it; per-class .cpp first-include doesn't
            # change.
            # `:int_literals_hpp` / `:int_literals_cpp` carry the
            # interned-Integer optimisation: extern decls + raw
            # int64_t tables in the .hpp, storage definitions in
            # the .cpp. Per-TU only parses cheap extern lines; the
            # constructor calls are paid once in
            # frozone_int_literals.cpp.
            @outs = { base: +"", post: +"", layouts: +"", all_hpp: +"", default: +"", universe: +"", static: +"", main: +"", int_literals_hpp: +"", int_literals_cpp: +"" }
            @stream = :default
            @indent = 0
            @strict_emit = false
            # Per-host-class set of other classes referenced in its method
            # bodies — populated by collect_call_surface's AST walk via
            # const_path_to_class. Used by ClassEmitter to emit precise
            # per-.cpp `#include "class/<Name>.hpp"` lines (Stage 3 Path 1
            # of the layouts.hpp split; project_layouts_split.md).
            # Key: host class name (Symbol/String — same as the class's
            # `.name` attribute on the Vm::ClassObject).
            @host_class_refs = Hash.new { |h, k| h[k] = Set.new }
            # Per-host-class set of intrinsic categories referenced in
            # its method bodies. Populated by collect_call_surface's
            # AST walk via IntrinsicLowering.category_for. Drives
            # per-class-TU `#include "intrinsics/<cat>_intrinsics.hpp"`
            # emission — same precise-includes pattern as
            # host_class_refs (Stage 3 of the layouts.hpp split).
            @host_intrinsic_refs = Hash.new { |h, k| h[k] = Set.new }
          end

          attr_reader :host_class_refs, :host_intrinsic_refs

          # Switch active output stream for the duration of the block.
          # Restores prior stream on exit (including via exception).
          # Auto-creates the stream if it doesn't exist (per-class
          # streams in step 7 are created on demand: :class_Object,
          # :class_Integer, ... rather than pre-declared in initialize).
          def with_stream(name)
            saved = @stream
            @stream = name
            @outs[name] ||= +""
            yield
          ensure
            @stream = saved
          end

          def write(*strs) = strs.each { |s| @outs[@stream] << s }
          def line(str) = @outs[@stream] << ("  " * @indent) << str << "\n"
          def blank = @outs[@stream] << "\n"

          def indented
            @indent += 1
            yield
            @indent -= 1
          end

          # Run `yield` with output captured to a string buffer (indent
          # reset). Used for rendering method bodies into RubyClass.overrides
          # body strings — writers commit via line/indented as usual,
          # but the result accumulates into a returned string instead of
          # the active stream's buffer. ensure-restore so a yield that
          # raises (e.g. graceful-degradation EmissionError) doesn't leak
          # the inner buffer into subsequent writes.
          # Note: routes through @stream selector so writes during capture
          # land in the captured buffer regardless of caller stream.
          def capture
            saved_buf = @outs[@stream]
            saved_indent = @indent
            @outs[@stream] = +""
            @indent = 0
            yield
            @outs[@stream]
          ensure
            @outs[@stream] = saved_buf
            @indent = saved_indent
          end

          def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
            @execute_block = execute_block
            @top_level_scope = top_level_scope
            @globals = globals
            @stub_file = stub_file
            @user_constants = collect_user_constants
            @user_classes = collect_all_classes
            @visibility_survey = VisibilitySurvey.compute(@user_classes)
            $stderr.puts VisibilitySurvey.format_summary(@visibility_survey)
            @cpp = Cpp.new(user_classes: @user_classes, user_constants: @user_constants)
            @cpp.emit = self
            # Load-phase object-graph snapshot: discover all reachable
            # objects from the roots (constants + class/module ivars +
            # cvars), assign identity-preserving slots, and route every
            # subsequent emit_vm_value through them. Built before accessor
            # emission + decorate_eigenclasses (which calls emit_vm_value).
            @snapshot = Snapshot.new(@cpp)
            register_snapshot_roots(@snapshot)
            warn "[snapshot] partition #{@snapshot.partition_report.inspect}" if ENV['FROZONE_SNAPSHOT_STATS'] == '1'
            @cpp.snapshot = @snapshot
            @call_surface = collect_call_surface
            @const_surface = collect_dynamic_constant_surface
            print_method_def_analysis if ENV['FROZONE_BOX_ANALYSIS'] == '1'
            @natural_arity_names = {}
            @multi_arity_table = {}
            @kw_unset_table = {}
            @leaf_dispatch_table = {}
            # FROZONE_NATURAL_ARGS + FROZONE_LEAF_DISPATCH default ON since
            # #160. Explicit disable: =0 / =false / =off / =no / empty.
            # FROZONE_ALL_OPTS=1 kept as a no-op alias for back-compat
            # with external scripts that used it as the umbrella flag.
            _all_opts_alias = ENV['FROZONE_ALL_OPTS']
            if ENV['FROZONE_METHOD_SHAPES'] == '1' || env_opt_enabled?('FROZONE_NATURAL_ARGS') || env_opt_enabled?('FROZONE_LEAF_DISPATCH')
              agg = build_method_shape_survey
              MethodShapeSurvey.report(agg) if ENV['FROZONE_METHOD_SHAPES'] == '1'
              if env_opt_enabled?('FROZONE_NATURAL_ARGS')
                # Eligibility table includes block-bearing defs and
                # yield / block_given? bodies as has_block:true sigs.
                # The slot decl + body carry a trailing `Proc* block`
                # param; the universal-slot trampoline casts its block
                # arg and forwards. multi_arity + kw_unset still
                # exclude block-bearing names — their signatures have
                # no block slot yet.
                hand_coded = compute_hand_coded_disqualified_names
                ibu = @internal_block_users || Set.new
                @natural_arity_names = MethodShapeSurvey.eligibility_table(
                  agg, exclude: hand_coded, internal_block_users: ibu,
                )
                @multi_arity_table = MethodShapeSurvey.multi_arity_table(agg, exclude: hand_coded | ibu)
                @kw_unset_table = MethodShapeSurvey.kw_unset_table(agg, exclude: hand_coded | ibu)
                override_collisions = prune_override_arity_collisions
                multi_collisions = prune_multi_arity_override_collisions
                kw_unset_collisions = prune_kw_unset_override_collisions
                has_block_count = @natural_arity_names.values.count(&:has_block)
                $stderr.puts "[box-first] natural-args: #{@natural_arity_names.size} eligible names " \
                             "(#{has_block_count} has_block; " \
                             "excluded: #{hand_coded.size} hand-coded, " \
                             "#{override_collisions} cpp-name arity collisions); " \
                             "#{@multi_arity_table.size} multi-arity (defaults; -#{multi_collisions} override collisions); " \
                             "#{@kw_unset_table.size} kw-unset (-#{kw_unset_collisions} override collisions)"
              end
              # Leaf-dispatch eligibility (independent of natural-args).
              # Activated by FROZONE_LEAF_DISPATCH=1 — populates the
              # table; codegen consumes it via emit.leaf_dispatch_table.
              if env_opt_enabled?('FROZONE_LEAF_DISPATCH')
                # Phase A: exclude names that already get natural-args
                # dispatch — their trampoline already provides similar
                # benefits. Pure universal-sig single-def-leaf names
                # are the main Phase A target (the rest joins later).
                leaf_excl = compute_hand_coded_disqualified_names |
                            (@internal_block_users || Set.new) |
                            @natural_arity_names.keys.to_set |
                            @multi_arity_table.keys.to_set |
                            @kw_unset_table.keys.to_set
                @leaf_dispatch_table = compute_leaf_dispatch_table(agg, exclude: leaf_excl)
                by_k = @leaf_dispatch_table.values.group_by(&:size).transform_values(&:size).sort.to_h
                $stderr.puts "[box-first] leaf-dispatch: #{@leaf_dispatch_table.size} leaf names " \
                             "(#{compute_leaf_classes.size} leaf classes total; by K: #{by_k.inspect})"
              end
            end
            all_classes = overlay_universe_methods(Runtime::ALL_CLASSES) + build_user_class_defs
            all_eigenclasses = all_classes.map { |k| Runtime.eigenclass_for(k) }.compact
            decorate_eigenclasses_with_const_overrides(all_classes, all_eigenclasses)
            # Topo-sort by parent so each class's parent struct is fully
            # defined before the child in layouts.hpp. Required because
            # the C-form fusion makes NilClass : Frozone_Vm_ObjectObject —
            # the parent now lives among user classes, not before them.
            classes = topo_sort_by_parent(all_classes + all_eigenclasses)
            @class_ids_for_init = classes.each_with_index.to_h { |k, i| [k.name, i] }
            kernel_fns = Runtime::ALL_KERNEL_FNS + build_user_constant_accessors + @snapshot.alloc_fns
            with_stream(:base) { write_base_open }
            with_stream(:post) { write_post_open }
            with_stream(:layouts) { write_layouts_open }
            with_stream(:all_hpp) { write_all_hpp_open }
            with_stream(:int_literals_hpp) { write_int_literals_hpp_open }
            with_stream(:int_literals_cpp) { write_int_literals_cpp_open }
            with_stream(:universe) { write_universe_open }
            with_stream(:static) { write_static_open }
            write_header
            write_namespace_open
            ClassEmitter.write_runtime(self, classes: classes, call_surface: @call_surface, const_surface: @const_surface, kernel_fns: kernel_fns) do
              # __init_static_state__ goes to its own TU
              # (frozone_static.cpp) — huge AOT-captured constant
              # initializers live there.
              with_stream(:static) { write_static_state_init }
              write_snapshot_owner_tus
              write_main_object
            end
            with_stream(:base) { write_base_close }
            with_stream(:post) { write_post_close }
            with_stream(:all_hpp) { write_all_hpp_close }
            with_stream(:int_literals_hpp) { write_int_literals_hpp_close }
            with_stream(:int_literals_cpp) { write_int_literals_cpp_close }
            with_stream(:layouts) { write_layouts_close }
            with_stream(:universe) { write_universe_close }
            with_stream(:static) { write_static_close }
            # `frozone_main_impl` lives in the default stream so it has
            # direct visibility into the namespace's types. `int main()`
            # itself is extracted into its own stream — frozone_main.cpp
            # — as a tiny trampoline that calls frozone_main_impl.
            write_main_impl
            write_namespace_close
            with_stream(:main) { write_main_trampoline }
            @outs
          end

          private

          # Default-on opt switch: true unless ENV[name] is explicitly
          # disabled. Recognised off-values: "0", "false", "off", "no",
          # and "" (case-insensitive). Anything else (including "1",
          # "true", "yes", "on", or unset) means enabled. Used for the
          # dispatch-perf knobs (FROZONE_NATURAL_ARGS, FROZONE_LEAF_DISPATCH)
          # which default ON since #160.
          OFF_VALUES = Set.new(%w[0 false off no]).freeze
          def env_opt_enabled?(name)
            v = ENV[name]
            return true if v.nil?
            !OFF_VALUES.include?(v.downcase) && !v.empty?
          end

          # Sort classes so each class's `parent` (by name) appears
          # earlier than the class itself. Stable for siblings — a
          # class's relative position to non-ancestors is preserved.
          # Required because the C-form fusion makes NilClass etc.
          # depend on Frozone_Vm_ObjectObject (a user class) as their
          # struct base, breaking the prior assumption that runtime
          # classes always come before user classes.
          def topo_sort_by_parent(classes)
            by_name = classes.each_with_object({}) { |c, h| h[c.name] = c }
            visited = Set.new
            result = []
            visit = ->(c) {
              return if visited.include?(c.name)
              visited << c.name
              if c.parent && (parent_cls = by_name[c.parent])
                visit.call(parent_cls)
              end
              result << c
            }
            classes.each { |c| visit.call(c) }
            result
          end

          # Walk top_level_scope.constants_table for every Vm::ClassObject.
          # Skip Universe-seeded names (BasicObject, Object, Integer, Array,
          # etc.) — they have hand-coded backing already.
          UNIVERSE_NAMES = Set.new(Runtime::ALL_CLASSES.map(&:name)).freeze

          # Methods that the receiver-aware send widening would normally
          # pull into the surface but whose compiled bodies break the
          # C++ build. Blacklist them until the underlying emission
          # gaps are fixed. Each entry is a Ruby method name.
          WIDENING_BLACKLIST = %i[
            proc_curry
            chunk
          ].to_set.freeze

          # For each Universe class, find its corresponding
          # Vm::ClassObject in constants_table and compile any methods
          # whose cpp_name isn't already in Universe's hand-coded
          # overrides. The hand-coded ones win on conflict (they're
          # specialised to the C++ data structure); core/4.0/'s body
          # fills in the gaps. Same for eigenclass methods.
          def overlay_universe_methods(universe_classes)
            top = @top_level_scope.constants_table || {}
            by_name = universe_classes.each_with_object({}) { |k, h| h[k.name] = k }
            universe_classes.map do |klass|
              cls = top[klass.name.to_sym]
              next klass unless cls.is_a?(Vm::ModuleObject)
              hand_coded = ancestor_hand_coded_names(klass, by_name)
              # Ivars referenced by overlaid methods need fields on the
              # struct or `this->iv_X` won't compile. Collect them the
              # same way build_user_class_def does for user classes,
              # filtering out anything already in `members:` (some
              # entries — MatchData — declare iv_X by hand for non-nil
              # initial values), AND anything inherited from the C++
              # parent struct — re-declaring an inherited member would
              # shadow it.
              existing_ivar_names = (klass.members || []).filter_map { |line|
                line[/\biv_([A-Za-z_][A-Za-z_0-9]*)\b/, 1]
              }.to_set | inherited_ivar_names(klass)
              extra_ivars = collect_ivars(cls)
                .reject { |iv| existing_ivar_names.include?(iv) }
                .map { |iv| "BO* iv_#{iv} = nil_instance();" }
              own_hand_coded = (klass.hand_coded_method_names || []).to_set
              chains = class_method_chains(cls)
              klass.dup.tap do |k|
                k.overrides = overlay_overrides_chained(klass.name, klass.overrides || {}, chains, hand_coded, own_hand_coded, host_class: cls)
                # Eigenclass methods don't take super (no MRO walk for
                # def-self-X chains in box-first today), so the flat
                # path is enough.
                k.eigenclass_overrides = overlay_overrides(klass.eigenclass_overrides || {}, eigenclass_methods(cls), hand_coded)
                k.members = (k.members || []) + extra_ivars unless extra_ivars.empty?
              end
            end
          end

          # Union of hand_coded_method_names across the runtime ancestor
          # chain. The hand-coded methods on BasicObject (mm_is_a_q with
          # the IS_A LUT, m_freeze, m_class, …) are the load-bearing
          # implementations — overlaying their core/4.0/ Ruby twins via
          # virtual dispatch would shadow them and recurse.
          # With C-form fusion the chain may now pass through a user
          # class (Frozone_Vm_ObjectObject) en route to Object/
          # BasicObject. User classes don't carry hand_coded_method_names
          # but they do have a parent, so just walk past them — the
          # hand-coded entries live further up the chain on Object etc.
          def ancestor_hand_coded_names(klass, by_name)
            names = Set.new
            current = klass
            while current
              if current.respond_to?(:hand_coded_method_names)
                (current.hand_coded_method_names || []).each { |n| names << n }
              end
              # Resolve parent: RubyClass uses .parent (a String name);
              # Vm::ClassObject uses .superclass (another Vm::ClassObject).
              parent_name = if current.respond_to?(:parent) && current.parent.is_a?(String)
                              current.parent
                            elsif current.respond_to?(:superclass) && current.superclass.respond_to?(:full_name)
                              Reachability.flatten(current.superclass.full_name)
                            end
              break unless parent_name
              current = by_name[parent_name] || @user_classes[parent_name.to_sym]
            end
            names
          end

          def overlay_overrides(existing_overrides, vm_methods, hand_coded)
            merged = existing_overrides.dup
            vm_methods.each do |mname, m|
              cpp_name = Cpp.method_name(mname)
              next if merged.key?(cpp_name)
              next if hand_coded.include?(cpp_name)
              # Method-level reachability — drop unused overrides.
              next if ENV['FROZONE_BOX_NO_PRUNE'] == '1' && WIDENING_BLACKLIST.include?(mname)
              next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || @call_surface&.key?(cpp_name)
              spec = build_override(m, storage_name: mname)
              merged[cpp_name] = spec if spec
            end
            merged
          end

          # Chain-aware overlay: head of each chain → m_X (gated by
          # hand_coded + existing overrides), tail → sm_X__from_<Origin>
          # always emitted (no hand-coded equivalents of shadowed slots).
          # Walk a method body looking for any Ast::Super node. A method
          # whose body never `super`s doesn't need a sm_X__from_Y slot
          # for the next chain entry — pruning these tail slots is the
          # single biggest gen-size win when compiling Frozone-as-frozone.
          # Stops at nested method defs (their bodies have their own
          # chain context).
          def body_has_super?(node)
            return false if node.nil?
            return false if node.is_a?(Ast::MethodDef)
            return true if node.is_a?(Ast::Super)
            return false unless node.respond_to?(:children)
            node.children.any? { |c| body_has_super?(c) }
          end

          def method_calls_super?(method)
            return false unless method.respond_to?(:body)
            body_has_super?(method.body)
          end

          def overlay_overrides_chained(host_name, existing_overrides, chains, hand_coded, own_hand_coded = Set.new, host_class: nil)
            merged = existing_overrides.dup
            chains.each do |mname, entries|
              # Method-level reachability gate — same as build_chained_overrides.
              cpp_head = Cpp.method_name(mname)
              next if ENV['FROZONE_BOX_NO_PRUNE'] == '1' && WIDENING_BLACKLIST.include?(mname)
              next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || @call_surface&.key?(cpp_head)
              # Stage 3 refine: drop the chain when no self-receiver call
              # site can dispatch through this host (and surface isn't wide).
              next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || method_keepable_for_class?(cpp_head, host_class)
              # Two-level hand-coded check:
              # - if the host class itself hand-codes this name (e.g.
              #   Object's m_class / op_case_eq are load-bearing), the
              #   hand-coded virtual must win — never overlay it.
              # - otherwise, if an ANCESTOR hand-codes it, only emit
              #   when the user explicitly defined it on this class
              #   (origin == :self); inherited Ruby defs from
              #   Object/Kernel must NOT shadow the hand-coded ancestor
              #   via virtual dispatch (would infinitely recurse).
              has_hand_coded_ancestor = false
              if own_hand_coded.include?(cpp_head)
                next
              elsif hand_coded.include?(cpp_head)
                head_origin, _ = entries.first
                next if head_origin != :self
                has_hand_coded_ancestor = true
              end
              # Tail-pruning: only emit the next sm_X__from_Y slot when
              # the previous body actually calls `super`. Stops emission
              # the moment a body returns without super-ing — common case.
              prev_needs_super = true
              entries.each_with_index do |(origin, method), idx|
                break if idx.positive? && !prev_needs_super
                cpp_name = idx.zero? ? cpp_head : Cpp.shadowed_method_name(mname, origin)
                next if merged.key?(cpp_name)
                ctx = {
                  host_name: host_name, method_name: mname, origin_index: idx, chain: entries,
                  method_params: ((method.required_params || []) + (method.optional_params || []).map(&:first)).map { |p| MethodEmitter.local_cpp_name(p) },
                  # kw_params is set in from_super; here we only need
                  # positional. Super forwarding reads kw locals from
                  # the natural-arity sig in the survey table directly.
                }
                # Head override on top of hand-coded ancestor: if the
                # user's body fails to emit (unsupported intrinsic etc.),
                # drop the override so C++ inheritance reuses the
                # hand-coded parent rather than abort-stubbing the slot.
                fall_through = has_hand_coded_ancestor && idx.zero?
                spec = build_override(method, super_ctx: ctx, fall_through_on_error: fall_through, storage_name: mname)
                merged[cpp_name] = spec if spec
                prev_needs_super = method_calls_super?(method)
              end
            end
            merged
          end

          # Recursively walk constants_table from top-level. Nested
          # classes (`Parser::Ruby40`) get added with their flattened
          # name (`:Parser_Ruby40`) — matches what path_to_cpp_name
          # produces at call sites. Modules emit as struct + eigenclass
          # too — Math.sqrt / Blurhash.encode_rb dispatches through the
          # eigenclass exactly like a Class's class methods. Module
          # instances are never allocated; the struct is just a marker.
          def collect_all_classes
            all = collect_all_classes_unfiltered
            return all if ENV['FROZONE_BOX_NO_PRUNE'] == '1'
            reach = Reachability.compute(
              execute_block:        @execute_block,
              user_methods:         user_methods,
              top_level_scope:      @top_level_scope,
              universe_class_names: UNIVERSE_NAMES,
              all_classes:          all,
              # User constants instantiate their class via C++
              # `new XClass()` in the accessor body — no AST trace,
              # so we have to root them explicitly.
              instantiated_classes: @user_constants.values,
              # Hand-coded C++ class-body dependencies (RubyClass.uses:)
              # for universe classes. Regexp::m_initialize's C++ body
              # calling intrinsic_raise_regexp_error is the motivating
              # case — RegexpError isn't visible in any Ruby AST.
              class_uses:           Runtime.class_uses,
            )
            kept = all.select { |flat, _| reach.include?(flat) }
            if ENV['FROZONE_BOX_DEBUG'] == '1'
              $stderr.puts "[box-first] reachability pruning: #{kept.size}/#{all.size} user classes kept"
            end
            kept
          end

          # Walk top_level_scope.constants_table for every Vm::ClassObject
          # / Vm::ModuleObject. Not yet filtered by reachability — the
          # full set is the input to Reachability.compute.
          def collect_all_classes_unfiltered
            classes = {}
            seen = Set.new
            walk = ->(scope, prefix) {
              return if seen.include?(scope.object_id)
              seen << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                flat = Reachability.compose_flat(prefix, name)
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  # Filter both by emitted-name collision (universe names
                  # at top level) AND by Vm-identity (a nested constant
                  # like BasicObject::BasicObject points back at the
                  # universe class — including it as a "user class"
                  # would re-emit its methods, defeating the universe
                  # overlay). Compare by `full_name` since that's what
                  # the universe knows about.
                  vm_full = (val.full_name || val.name).to_s
                  is_universe = UNIVERSE_NAMES.include?(flat.to_s) || UNIVERSE_NAMES.include?(vm_full)
                  classes[flat] = val unless is_universe
                  walk.call(val, flat)
                end
              end
            }
            walk.call(@top_level_scope, nil)
            classes
          end

          # Recursively walk constants_tables for instance constants
          # (not classes/modules — those are user_classes). Both
          # top-level (`STDOUT`) and nested (`Encoding::BINARY`) get
          # collected with flattened names. Each gets a lazy-init
          # accessor `k_<flat>()` later. Skip primitive Vm types
          # (Symbol/Integer/String/etc.) — those emit as literals via
          # emit_vm_value, not as accessors.
          # Vm primitives that emit as literal expressions (intern,
          # new String, etc.) rather than default-constructed objects.
          PRIMITIVE_VM_VALUE_CLASSES = [
            Vm::IntegerObject, Vm::FloatObject, Vm::SymbolObject,
            Vm::StringObject, Vm::NilObject, Vm::TrueObject, Vm::FalseObject,
            Vm::ArrayObject, Vm::HashObject, Vm::RegexpObject
          ].freeze

          def primitive_vm_value?(val)
            PRIMITIVE_VM_VALUE_CLASSES.any? { |c| val.is_a?(c) }
          end

          # Recursively walk constants_tables for instance constants
          # (not classes/modules — those are user_classes). Both
          # top-level (`STDOUT`) and nested (`Encoding::BINARY`) get
          # collected with flattened names. Each gets an accessor
          # `k_<flat>()` later — primitives emit as literal
          # expressions, ObjectObjects as default-construct + ivar
          # populate from the snapshot.
          def collect_user_constants
            consts = {}
            # Owning source file per constant flat-name: the enclosing scope's
            # flat-name (its TU), or :main for top-level. Drives the snapshot's
            # object-graph distribution to owning TUs.
            @constant_owner = {}
            seen = Set.new
            walk = ->(scope, prefix) {
              return if seen.include?(scope.object_id)
              seen << scope.object_id
              owner = prefix || :main
              (scope.constants_table || {}).each do |name, val|
                flat = Reachability.compose_flat(prefix, name)
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  walk.call(val, flat)
                elsif val.is_a?(Vm::ObjectObject)
                  consts[flat] = val
                  @constant_owner[flat] = owner
                elsif val.is_a?(Vm::HoistedConstantSentinel)
                  # --hoist-class-consts moved this constant's initialiser
                  # to the execute phase. The slot is occupied by a sentinel
                  # at load time. Register it here so ConstantWrite at
                  # execute time can resolve the flat name and rebind the
                  # storage; build_user_constant_accessors detects the
                  # sentinel and emits a writable nil_instance() storage cell.
                  consts[flat] = val
                end
              end
              # Constants defined inside `class << self; ... end` live on
              # the eigenclass's constants_table, NOT the class's. They're
              # lexically visible to methods defined in the same block —
              # ConstantResolver walks the same prefix chain for both, so
              # the flat name is the same as a sibling top-level constant
              # of the host class. (E.g. `Intrinsics::CONST_NAME_RE` →
              # :Frozone_Vm_Intrinsics_CONST_NAME_RE, regardless of which
              # table holds the value.)
              eigen = scope.eigenclass rescue nil
              if eigen && eigen != scope
                (eigen.constants_table || {}).each do |name, val|
                  flat = Reachability.compose_flat(prefix, name)
                  next if consts.key?(flat)  # host-side wins if both exist
                  if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                    walk.call(val, flat)
                  elsif val.is_a?(Vm::ObjectObject)
                    consts[flat] = val
                    @constant_owner[flat] = owner
                  elsif val.is_a?(Vm::HoistedConstantSentinel)
                    consts[flat] = val
                  end
                end
              end
            }
            walk.call(@top_level_scope, nil)
            consts
          end

          # Seed the snapshot graph: constants + class/module instance
          # ivars + class variables are the load-phase roots. Discovery
          # closes over them transitively. (Eigenclass ivars and load-phase
          # globals are additional roots to add for completeness — both
          # currently zero-occurrence; covered by snapshot_spec test cases.)
          def register_snapshot_roots(snap)
            # Constants FIRST so a named object owns its k_<flat> accessor
            # (a later anon root referencing it would otherwise mint k_snap_N).
            @user_constants.each do |flat, val|
              next if val.is_a?(Vm::HoistedConstantSentinel)
              snap.register_constant(flat, val, owner: @constant_owner[flat] || :main)
            end
            # Then anonymous roots: class/module instance ivars + cvars. The
            # owning file is the class's own TU (its flat-name key).
            @user_classes.each do |flat, cls|
              (cls.instance_variables_hash || {}).each_value { |v| snap.register_anon(v, owner: flat) }
              if cls.respond_to?(:class_variables) && cls.class_variables
                cls.class_variables.each_value { |v| snap.register_anon(v, owner: flat) }
              end
            end
          end

          def build_user_constant_accessors
            @user_constants.filter_map do |name, val|
              # Slotted objects (String/Array/Hash/ObjectObject — including
              # the guest nil/true/false singletons, which are ObjectObjects
              # at the meta level) are emitted by Snapshot#alloc_fns with
              # identity-preserving accessors (canonical k_<flat> or a router
              # for aliases), so all references stay one object — skip here.
              next nil if @snapshot.slotted?(val)
              if val.is_a?(Vm::HoistedConstantSentinel)
                # --hoist-class-consts moved this constant's init to the
                # execute phase. The slot starts as nil_instance() and gets
                # rebound by the hoisted ConstantWrite at runtime via the
                # reference-returning accessor.
                next Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BO*& k_#{name}()",
                  body: "static BO* val = nil_instance(); return val;",
                )
              end
              if primitive_vm_value?(val)
                # Primitive — emit_vm_value gives the literal expr.
                # Cached in a static for identity stability + skip
                # re-evaluation cost on subsequent calls.
                # Fail-hard on capture failure: silent fallback to
                # nil_instance produced confusing downstream NoMethodError
                # cascades (e.g. Officious's Procs failed → Hash captured
                # as nil → Officious.each at runtime → NoMethodError on
                # nil). Per the project fail-early stance, surface the
                # gap at compile time with file:line so it's obvious
                # what to fix next.
                expr =
                  begin
                    @cpp.emit_vm_value(val)
                  rescue Cpp::EmissionError => e
                    raise Cpp::EmissionError, "constant #{name}: #{e.message} (silent-fallback removed; implement proper static-init or hoist to runtime — see docs/box-first-load-execute-split.md)"
                  end
                # Return-by-reference so ConstantWrite can rebind the
                # storage via `(k_FOO() = newval)`. Read sites still
                # compile unchanged — `BO*&` auto-converts to
                # `BO*` everywhere a pointer is expected.
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BO*& k_#{name}()",
                  body: "static BO* val = #{expr}; return val;",
                )
              else
                # Snapshot ObjectObject — default-construct (no
                # m_initialize call), let __init_static_state__
                # populate ivars from the Vm instance.
                klass_name = Reachability.flatten(val.class_object.full_name)
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BO*& k_#{name}()",
                  body: "static BO* val = new #{klass_name}(); return val;",
                )
              end
            end
          end

          # All Vm::Method instances on the class. Closed-world: we emit
          # bodies for ALL methods regardless of source — when a body
          # contains an AST shape we can't yet handle, build_override
          # rescues the EmissionError and skips just that method (it
          # falls through to method_missing at runtime). The filter that
          # excludes methods aliased into the class via Object inheritance
          # remains — those get emitted on MainObject.
          def class_methods(cls)
            ModuleFlattening.flatten(cls, direct_methods(cls))
          end

          # MRO-ordered chain map for cls's flattened methods. Head of
          # each chain is the winning method (matches `class_methods`);
          # tail entries are the shadowed methods super walks into.
          # Used by override emission to lay down `sm_X__from_<Origin>`
          # slots and by Ast::Super lowering to find its target.
          def class_method_chains(cls)
            ModuleFlattening.chain(cls, direct_methods(cls))
          end

          def direct_methods(cls)
            # When cls IS @top_level_scope (i.e. we're overlaying Object
            # itself), every entry would match the top-level filter and
            # the overlay would come back empty — wiping Object#itself,
            # #dup, #to_s, etc. The filter only matters for descendants.
            top_level_methods = cls.equal?(@top_level_scope) ? {} : (@top_level_scope.methods_table || {})
            (cls.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method)
              # Frozone's Vm copies included-module methods into each
              # including class's methods_table (so dispatch is a single
              # hash lookup). For chain attribution we need the original
              # defining class — check method.scopes.last. If it ISN'T
              # cls, the method was inherited via include, not defined
              # here. Skip it from direct_methods so `chain` doesn't
              # misclassify it as a :self entry (which would defeat the
              # hand-coded-ancestor gate for mm_is_a_q / mm_respond_to_q
              # and produce self-recursive Kernel#is_a? bodies on every
              # subclass).
              defining_scope = m.respond_to?(:scopes) ? m.scopes&.last : nil
              next false if defining_scope && !defining_scope.equal?(cls)
              top_level_methods[name] != m
            end
          end

          # Method-level reachability. cpp_method_name → ruby_method_name
          # for every method actually invoked from a reachable AST node
          # — iterated to fixpoint. Seed: execute_block + top-level user
          # methods. When a new method name enters the surface, all
          # bodies that implement it (across reachable classes + universe
          # overlays) are scheduled for AST walking, which can pull in
          # more method names.
          #
          # Pre-aggressive-pruning version also dumped EVERY defined-
          # method-name into the surface, which kept ~1200 entries even
          # for trivial scripts. The new version keeps only what's
          # transitively called, plus a tiny set of auto-included
          # fallback names (m_new / m_initialize / m_class /
          # mm_respond_to_q / m_method_missing / m_const_missing).
          def collect_call_surface
            calls = {}
            seen_ruby_names = Set.new
            reached_bodies = Set.new
            worklist = []
            symbol_literals = Set.new
            # Stage 3: per-(class, method) pruning via cheap self-receiver
            # inference. @call_surface_filter[cpp_name] is either:
            #   nil   → wide; some unknown-receiver call site exists,
            #           keep this method on every class that defines it.
            #   Set   → narrow; only call sites we saw were self-receiver
            #           inside the listed host classes. Class C's
            #           override survives only if some D in the set has
            #           C in its MRO (C is reachable from a D-instance
            #           dispatch). See method_keepable_for_class?.
            # Default unset is treated as wide too — safety first.
            call_surface_filter = {}

            schedule_body = lambda do |body, host_calls, host_refs|
              next if body.nil?
              key = [body.object_id, host_calls&.object_id, host_refs&.object_id]
              next unless reached_bodies.add?(key)
              worklist << [body, host_calls, host_refs]
            end

            # Track Ruby names separately from cpp_names because the
            # encoding can collide: `:=~` → `op_match_op` clashes with
            # a regular `def match_op` (the parser gem has both). When
            # we discover a NEW Ruby name we still schedule its
            # implementing bodies even if its cpp_name was already
            # added under a different Ruby name — otherwise the
            # second-named-method's body never gets walked, and its
            # transitively-called methods (`send_binary_op_map` etc.)
            # don't make it into the surface.
            register_method = lambda do |ruby_name|
              cpp_name = Cpp.method_name(ruby_name)
              calls[cpp_name] ||= ruby_name.to_s
              if seen_ruby_names.add?(ruby_name)
                method_bodies_named_with_host(ruby_name).each do |b, hc, hr|
                  schedule_body.call(b, hc, hr)
                end
              end
              cpp_name
            end

            mark_wide = lambda do |ruby_name|
              cpp_name = register_method.call(ruby_name)
              call_surface_filter[cpp_name] = nil  # wide → keep on every class
            end

            mark_self = lambda do |ruby_name, host|
              cpp_name = register_method.call(ruby_name)
              # Once wide, stays wide.
              return if call_surface_filter.key?(cpp_name) && call_surface_filter[cpp_name].nil?
              set = (call_surface_filter[cpp_name] ||= Set.new)
              set << host if host
            end

            send_method_names = %i[send __send__ public_send].freeze
            # Resolve an Ast::ConstantRead / Ast::ConstantPath chain to
            # a Vm::ClassObject by matching the dotted path against
            # @user_classes flat-name keys. Returns nil for runtime-
            # variable receivers, deeply-qualified shapes we don't
            # recognise, or constants pointing at non-class values.
            # Resolves an Ast::ConstantRead / ConstantPath chain to the
            # known user class (or universe class) it refers to.
            # Returns [cls, flat_name] — cls is the Vm::ClassObject
            # (or nil for universe classes); flat_name is the
            # underscore-joined symbol that doubles as the C++ struct
            # name and per-class hpp filename.
            #
            # Uses Reachability.resolve_const_to_flat for proper
            # lexical-scope walking — `Method` referenced inside
            # `Frozone::Vm::Vm` resolves to `Frozone_Vm_Method`, not
            # the top-level `Method`. Without this, `host_class_refs`
            # would record the wrong class and per-class .cpp would
            # miss the include it actually needs (Stage 4 of the
            # layouts.hpp split).
            #
            # `scope_prefixes` defaults to empty (top-level only) for
            # the existing eigenclass-widening caller; the AST-walk
            # caller passes the host's actual scope chain.
            const_path_to_class = lambda do |recv, scope_prefixes = []|
              flat = Reachability.resolve_const_to_flat(recv, scope_prefixes, @user_classes)
              return [@user_classes[flat], flat] if flat && @user_classes.key?(flat)
              # Bare path with universe-class name (BasicObject,
              # Integer, FloatDomainError, ...) — these aren't in
              # @user_classes but have their own class/<Name>.hpp.
              parts = Reachability.collect_path(recv)
              tail = parts.join('_').to_sym
              return [nil, tail] if UNIVERSE_NAMES.include?(tail.to_s)
              nil
            end
            walk = lambda do |node, host, host_refs|
              next unless node.is_a?(Ast::Node)
              # Don't recurse into nested method defs — their bodies are
              # walked separately via user_methods/method_bodies_named
              # with their own host class.
              return if node.is_a?(Ast::MethodDef)
              if node.is_a?(Ast::MethodCall) || node.is_a?(Ast::AttributeWrite)
                if implicit_self_receiver?(node)
                  mark_self.call(node.name, host)
                else
                  mark_wide.call(node.name)
                end
              end
              # `recv.x ||=/&&=/+= val` invokes both x and x= on recv. Both
              # need wide-vtable slots, since the receiver type isn't
              # statically known here (it's the recv expression). The
              # operator (for op=) dispatches on the current value, which is
              # also a wide call.
              if node.is_a?(Ast::CallOrWrite) || node.is_a?(Ast::CallAndWrite) || node.is_a?(Ast::CallOperatorWrite)
                mark_wide.call(node.read_name)
                mark_wide.call(node.write_name)
                mark_wide.call(node.operator) if node.is_a?(Ast::CallOperatorWrite)
              end
              if node.is_a?(Ast::MethodCall) || node.is_a?(Ast::AttributeWrite)
                # Receiver-aware send widening. When we see
                # `Const.send(name_expr)` and `Const` resolves to a
                # known class, mark every eigenclass method of that
                # class as wide. This is the principled fix for
                # `Vm::Intrinsics.send(@name, ...)` in IntrinsicCall:
                # the dispatched name is a runtime ivar, not a literal,
                # so the literal-Symbol widening can't see it — but
                # the receiver is statically resolvable, so we know
                # which class's methods are reachable.
                if node.is_a?(Ast::MethodCall) &&
                   send_method_names.include?(node.name) &&
                   node.receiver_node
                  cls, _flat = const_path_to_class.call(node.receiver_node)
                  if cls && (eig = (cls.eigenclass rescue nil))
                    (eig.methods_table || {}).each_key do |m|
                      # Methods known to break the C++ build when emitted
                      # under box-first today — kwarg `block:` parameter,
                      # references to hand-coded methods that don't exist
                      # on the receiver (mm_absolute_path_q, mm_linear_time_q,
                      # m_newly_created_for_subclass), Hash literal init
                      # shape mismatches. Drop until those emission gaps
                      # close. Hits if `_curry`-style helpers ever flow
                      # through this widening; right now `proc_curry` is
                      # the main offender during frozone-as-frozone build.
                      next if WIDENING_BLACKLIST.include?(m)
                      mark_wide.call(m)
                    end
                  end
                end
              elsif node.is_a?(Ast::SymbolLiteral)
                # Collect every symbol literal that names a method.
                # We can't add to surface eagerly — most literals
                # aren't method-name references (`{foo: 1}`, hash
                # keys, etc.). But racc-style code stores
                # `:_reduce_42` symbols in a static table and
                # dispatches via `__send__`. After the main walk we
                # check if any send-like dispatch is in the surface;
                # if yes, every collected literal that names a
                # method gets added. See the post-walk loop below.
                symbol_literals << node.value.to_sym
              elsif node.is_a?(Ast::BlockArg) && node.value_node.is_a?(Ast::SymbolLiteral)
                # `&:upcase` synthesises a SymbolProc that calls the
                # named method on its first arg — see lambda_emitter's
                # from_block_as_proc. Emission requires the slot to
                # exist on BasicObject's universal surface, so widen
                # eagerly (don't wait for the conditional post-walk).
                mark_wide.call(node.value_node.value.to_sym)
              elsif (node.is_a?(Ast::ConstantRead) || node.is_a?(Ast::ConstantPath)) && host_refs
                # Stage 3 Path 1: any AST node that resolves to a
                # known class via const_path_to_class becomes an
                # entry in host_class_refs[<host_refs_flat_name>].
                # host_refs is the ENCLOSING class — the class whose
                # methods_table this body was found in. Critical for
                # overlaid methods: an Enumerable method that's been
                # overlaid into Array gets its refs attributed to BOTH
                # Array and Enumerable (via two visit() calls in
                # method_bodies_named_with_host), so each .cpp gets
                # the includes its emitted body needs.
                # Pass the host's scope chain so `Method` inside
                # Frozone::Vm::Vm resolves to Frozone_Vm_Method (not
                # top-level Method). For eigenclass hosts use the
                # OWNER's scope — the eigenclass's full_name is
                # `#<Class:Foo>`-style, useless for resolution.
                # Stage 4 of the layouts.hpp split depends on this
                # being precise.
                scope_owner =
                  if host_refs.respond_to?(:is_singleton_class) && host_refs.is_singleton_class
                    host_refs.singleton_of
                  else
                    host_refs
                  end
                scope = scope_owner.respond_to?(:full_name) ? Reachability.scope_for_class(scope_owner) : []
                resolved = const_path_to_class.call(node, scope)
                if resolved
                  # Compute the host's flat name for indexing.
                  # Eigenclasses (`is_singleton_class`) get a synthetic
                  # `<OwnerFlat>_eig` form that matches the
                  # RubyClass naming convention used by ClassEmitter
                  # (k.name on the consumption side).
                  host_flat =
                    if host_refs.respond_to?(:is_singleton_class) && host_refs.is_singleton_class
                      owner = host_refs.singleton_of
                      if owner.respond_to?(:full_name) && owner.full_name
                        Reachability.eigenclass_flat(owner)
                      elsif owner
                        :"#{owner.name}#{Reachability::EIG_SUFFIX}"
                      end
                    elsif host_refs.respond_to?(:full_name) && host_refs.full_name
                      Reachability.flatten(host_refs.full_name).to_sym
                    else
                      host_refs.name.to_s.to_sym
                    end
                  @host_class_refs[host_flat] << resolved[1] if host_flat
                  if ENV['FROZONE_BOX_REFS_DEBUG'] == '1'
                    $stderr.puts "[refs] #{host_flat} -> #{resolved[1]}"
                  end
                end
              elsif node.is_a?(Ast::IntrinsicCall) && host_refs
                # Per-TU intrinsic-category tracking. Each call site
                # contributes one entry in @host_intrinsic_refs so
                # class_emitter.rb can emit only the category headers
                # this TU actually needs (drops per-TU header parse
                # from ~14 categories to typically 1-3). category_for
                # returns nil for TEMPLATE-only intrinsics that don't
                # need a header.
                cat = IntrinsicLowering.category_for(node.name)
                if cat
                  host_flat =
                    if host_refs.respond_to?(:is_singleton_class) && host_refs.is_singleton_class
                      owner = host_refs.singleton_of
                      if owner.respond_to?(:full_name) && owner.full_name
                        Reachability.eigenclass_flat(owner)
                      elsif owner
                        :"#{owner.name}#{Reachability::EIG_SUFFIX}"
                      end
                    elsif host_refs.respond_to?(:full_name) && host_refs.full_name
                      Reachability.flatten(host_refs.full_name).to_sym
                    else
                      host_refs.name.to_s.to_sym
                    end
                  @host_intrinsic_refs[host_flat] << cat if host_flat
                end
              end
              node.children.each { |c| walk.call(c, host, host_refs) } if node.respond_to?(:children)
            end

            # Seed pre-walk:
            #   - Hand-coded universe overrides + hand_coded_method_names
            #     live directly on the class struct and need slots on
            #     BasicObject's universal surface for `override` to
            #     type-check on derived classes.
            #   - Auto-included fallbacks referenced from generated code
            #     (m_new, m_initialize, m_class, mm_respond_to_q,
            #     m_method_missing, m_const_missing).
            # All seeded BEFORE the walk loop so transitive references
            # from their implementing bodies get picked up.
            seed_names = Set.new
            # FROZONE_BOX_NO_PRUNE: seed every method on every class so
            # the universal surface declares them all, and method bodies
            # that call any name of these methods compile without
            # missing-member errors. This is the "give up on pruning,
            # accept ~2× gen growth" path used to debug runtime
            # divergences from MRI without conflating with pruning gaps.
            if ENV['FROZONE_BOX_NO_PRUNE'] == '1'
              all_method_names = Set.new
              # Walk every Vm-level class reachable from the top-level
              # scope (covers universe classes like String/Array AND
              # @user_classes), plus their eigenclasses.
              seen = Set.new
              walk_methods = lambda do |scope|
                return if seen.include?(scope.object_id)
                seen << scope.object_id
                (scope.methods_table || {}).each_key { |n| all_method_names << n }
                eig = scope.eigenclass rescue nil
                (eig&.methods_table || {}).each_key { |n| all_method_names << n } if eig
                (scope.constants_table || {}).each_value do |val|
                  walk_methods.call(val) if val.is_a?(Vm::ModuleObject)
                end
              end
              walk_methods.call(@top_level_scope)
              # Skip method names whose emitted bodies break the C++
              # build (kwarg-name-as-local-var emission bugs etc.).
              # See WIDENING_BLACKLIST.
              all_method_names.each { |n| mark_wide.call(n) unless WIDENING_BLACKLIST.include?(n) }
            end
            # m_hash_value is a C++-internal hook (returns std::size_t,
            # used by unordered_map<BO*, ...>) — not a Ruby
            # method despite the m_ prefix. Excluded from METHOD_VT
            # since its signature doesn't match the universal protocol.
            non_ruby_hand_coded = %w[m_hash_value].to_set
            Runtime::ALL_CLASSES.each do |k|
              (k.overrides || {}).each_key { |cpp| seed_names << cpp unless cpp.start_with?("c_", "sm_") || non_ruby_hand_coded.include?(cpp) }
              (k.hand_coded_method_names || []).each { |cpp| seed_names << cpp unless cpp.start_with?("c_", "sm_") || non_ruby_hand_coded.include?(cpp) }
            end
            # m_hash / mm_eql_q are called unconditionally by the runtime
            # Hash's Hasher/KeyEq (Ruby hash/eql? key protocol), so they must
            # always be declared on BasicObject even when an app never names
            # `hash`/`eql?` (otherwise pruned app builds fail to compile).
            seed_names.merge(%w[m_new m_initialize m_class mm_respond_to_q m_method_missing m_const_missing m_hash mm_eql_q])
            # Frozone::Vm::Intrinsics is special: its eigenclass methods
            # are dispatched purely by Ast::IntrinsicCall#evaluate at
            # runtime via `Vm::Intrinsics.send(@name, ...)`. The @name is
            # a Symbol stored in the AST node — never a literal in any
            # statically-walkable source — so neither the main walk nor
            # the send-aware widening can root these methods.
            #
            # Ideal: seed every Intrinsics eigenclass method. In practice
            # some method bodies hit emission bugs (kwarg block: param,
            # references to hand-coded methods that don't exist, etc.)
            # that crash the C++ build when emitted. For now seed an
            # explicit allow-list of methods we know we need for
            # /tmp/hello.rb's load_core path. Grow as we hit gaps.
            intrinsics_cls = @user_classes[:Frozone_Vm_Intrinsics] rescue nil
            if intrinsics_cls && (intrinsics_cls.eigenclass rescue nil)
              # Seed every Intrinsics eigenclass method. core/4.0/ dispatches
              # to Intrinsics.X via Ast::IntrinsicCall#evaluate at runtime
              # using `Vm::Intrinsics.send(@name, ...)` — the @name is a
              # Symbol literal in the AST node, never reachable via static
              # walking, so without seeding the entire surface, methods
              # silently drop and you get NoMethodError on first call.
              # Body emission failures are caught by method_emitter's
              # rescue and produce abort stubs — calling an unimplemented
              # intrinsic aborts loudly with the specific feature gap,
              # which is what we want.
              #
              # SOME bodies succeed Ruby-level emission but produce invalid
              # C++ (e.g. `block:` kwarg in a block-parameter list) that
              # fails g++ compile. Exclude those by name until their
              # lowering is fixed — they fall through to mm_dispatch →
              # NoMethodError at runtime, same as before this expansion.
              skip = %i[
                proc_curry
              ].to_set
              mt = intrinsics_cls.eigenclass.methods_table || {}
              mt.each_key do |mname|
                next if skip.include?(mname)
                seed_names << Cpp.method_name(mname)
              end
            end
            # Seeded names are universally reachable — runtime dispatches
            # them generically (m_class on any object, m_send via __send__),
            # so widen the surface filter.
            seed_names.each { |cpp| mark_wide.call(cpp_name_to_ruby(cpp).to_sym) }

            # Pull literal Symbols out of user_constants too. Class
            # body initializations (e.g. racc's `Racc_arg = [...,
            # racc_reduce_table, ...]` containing `:_reduce_NNN`
            # symbols) run at load time and survive only as the
            # frozen runtime value. The original AST is gone by the
            # time the surface walker runs, so we'd miss those
            # symbols. Recursively scan user_constants for
            # SymbolObjects to feed the send-aware widening.
            collect_symbols_from_constants = lambda do |val, depth = 0|
              return if depth > 10
              if val.is_a?(Vm::SymbolObject)
                symbol_literals << val.raw
              elsif val.is_a?(Vm::ArrayObject)
                val.raw.each { |e| collect_symbols_from_constants.call(e, depth + 1) }
              elsif val.is_a?(Vm::HashObject)
                # Skip — keys/values via Hash internals are awkward
                # and rarely contain method-name symbols.
              end
            end
            @user_constants.each_value { |v| collect_symbols_from_constants.call(v) }

            # Top-level execute body runs on `main` (an Object instance) —
            # bare calls in it dispatch through Object's MRO. Treat the
            # host as @top_level_scope (Object) for self-call attribution.
            # No enclosing class for top-level body → host_refs nil
            # (refs would land in Object via the universe-class visit
            # in method_bodies_named_with_host's loop, anyway).
            schedule_body.call(@execute_block, @top_level_scope, nil)
            user_methods.each_value do |m|
              next unless m.is_a?(Vm::Method)
              host = m.scopes.last
              method_walkable_roots(m).each { |r| schedule_body.call(r, host, host) }
            end

            # Send-aware widening: when send-style dispatch is in the
            # surface, treat every literal Symbol that names a method
            # as if it were a direct method call. Sound for
            # closed-world AOT as long as the dispatched name appears
            # literally somewhere in the program (racc tables do; so
            # do most define_method tables, attr_* expansions, etc.).
            # Iterate to fixpoint — newly-discovered bodies can
            # contribute more send-like calls or more literal
            # symbols, requiring another widening pass.
            send_names = %w[m_send m___send__ m_public_send].to_set
            until worklist.empty?
              while (item = worklist.shift)
                body, host_calls, host_refs = item
                walk.call(body, host_calls, host_refs)
              end
              if send_names.any? { |n| calls.key?(n) }
                progressed = false
                symbol_literals.each do |sym|
                  bodies = method_bodies_named_with_host(sym)
                  next if bodies.empty?
                  # __send__ dispatch is unknown-receiver by definition —
                  # widen the surface for every literal Symbol that names
                  # a real method, EVEN IF it was previously seen as a
                  # self-call. Otherwise classes whose only call path is
                  # via __send__(:foo) (e.g. OptionParser_List#search,
                  # reached only through visit's `el.__send__(:search)`)
                  # get their override pruned. Track progress on filter
                  # transitions and on newly-scheduled bodies.
                  prev_filter = call_surface_filter[Cpp.method_name(sym)]
                  prev_seen = seen_ruby_names.include?(sym)
                  mark_wide.call(sym)
                  progressed ||= prev_filter != nil || !prev_seen
                end
                break unless progressed
              end
            end

            if ENV['FROZONE_BOX_DEBUG'] == '1'
              wide_count = call_surface_filter.count { |_, v| v.nil? }
              narrow_count = call_surface_filter.count { |_, v| !v.nil? }
              $stderr.puts "[box-first] method-level surface: #{calls.size} methods (#{wide_count} wide, #{narrow_count} self-narrow)"
              if (target = ENV['FROZONE_BOX_DEBUG_SURFACE'])
                $stderr.puts "[box-first] surface[#{target}] = #{call_surface_filter[target].inspect}"
              end
            end
            @call_surface_filter = call_surface_filter
            calls
          end

          # True if a MethodCall / AttributeWrite has an implicit `self`
          # receiver (no explicit receiver, or an explicit `self` literal).
          # The dispatch then walks the surrounding host class's MRO.
          def implicit_self_receiver?(node)
            r = node.receiver_node
            r.nil? || r.is_a?(Ast::SelfLiteral)
          end

          # Like method_bodies_named but tags each body with the host
          # class it was defined on, so the worklist can attribute
          # self-receiver call sites inside the body to the right MRO.
          def method_bodies_named_with_host(name)
            pairs = []
            # Two hosts per body:
            #   host_calls = m.scopes.last (the class where the method
            #     was originally defined; existing call_surface widening
            #     keys filters off this).
            #   host_refs  = enclosing_cls (the class whose methods_table
            #     we found this method in — Array for an Enumerable
            #     method that's been overlaid into Array). Per-class
            #     `.cpp` emit needs refs collected against host_refs so
            #     Array.cpp's includes cover the Enumerable methods that
            #     end up baked into it.
            # Same body may appear in multiple tables (e.g. Enumerable's
            # to_set and Array's overlaid copy point to the same Vm::Method);
            # walking both pairs adds refs to both host_class_refs[Array]
            # and host_class_refs[Enumerable], which is what we want.
            push = lambda do |m, enclosing_cls|
              next unless m.is_a?(Vm::Method)
              host_calls = m.scopes.last
              method_walkable_roots(m).each { |r| pairs << [r, host_calls, enclosing_cls] }
            end
            visit = lambda do |cls|
              next unless cls.is_a?(Vm::ModuleObject)
              push.call((cls.methods_table || {})[name], cls)
              eig = cls.eigenclass rescue nil
              push.call((eig.methods_table || {})[name], eig) if eig
            end
            @user_classes.each_value(&visit)
            top = @top_level_scope.constants_table || {}
            Runtime::ALL_CLASSES.each do |universe_klass|
              visit.call(top[universe_klass.name.to_sym])
            end
            top_m = user_methods[name]
            push.call(top_m, nil) if top_m
            pairs
          end

          # Stage-3 keep predicate: should `cpp_name` be emitted as an
          # override on `klass` (a Vm::ClassObject / Vm::ModuleObject)?
          # Returns true when the call surface filter is wide (any
          # unknown-receiver site exists) or when at least one
          # self-call-site host class can dispatch through klass via
          # its MRO.
          def method_keepable_for_class?(cpp_name, klass)
            return true unless @call_surface_filter
            return true unless @call_surface_filter.key?(cpp_name)
            filter = @call_surface_filter[cpp_name]
            return true if filter.nil?  # wide
            return false if klass.nil?
            filter.any? { |host| dispatch_can_land_on?(host, klass) }
          end

          # True iff a host-instance dispatch could land on klass.
          # Two cases:
          # - klass is in host's ancestor chain (host inherits from
          #   klass or includes module klass) — usual upward case
          # - klass is a descendant of host — bare `foo` inside host's
          #   body has runtime receiver = some E.is_a?(host), so
          #   dispatch on E's vtable can land on E or any class
          #   between E and host. Without the downward walk we'd
          #   prune `Parser::Base#m_next_token` (defined in a
          #   subclass of Racc::Parser, which has the bare self-call
          #   in its driver) and dispatch would fall through to
          #   Racc's NotImplementedError stub.
          def dispatch_can_land_on?(host, klass)
            return true if host.equal?(klass)
            return false unless host.is_a?(Vm::ModuleObject)
            return false unless klass.is_a?(Vm::ModuleObject)
            return true if (host.ancestors_list rescue []).any? { |a| a.equal?(klass) }
            (klass.ancestors_list rescue []).any? { |a| a.equal?(host) }
          end

          # Find every Vm::Method body that implements `name` on a
          # reachable class or universe-overlay class. Includes both
          # instance-table and eigenclass-table entries. Used by
          # collect_call_surface to expand the worklist.
          def method_bodies_named(name)
            result = []
            push_method = lambda do |m|
              next unless m.is_a?(Vm::Method)
              result.concat(method_walkable_roots(m))
            end
            visit = lambda do |cls|
              next unless cls.is_a?(Vm::ModuleObject)
              push_method.call((cls.methods_table || {})[name])
              eig = cls.eigenclass rescue nil
              push_method.call((eig.methods_table || {})[name]) if eig
            end
            @user_classes.each_value(&visit)
            top = @top_level_scope.constants_table || {}
            Runtime::ALL_CLASSES.each do |universe_klass|
              visit.call(top[universe_klass.name.to_sym])
            end
            # Top-level user methods (defined on Object directly) live
            # at the top-level scope's methods_table, not on a class.
            (user_methods[name]&.body && [user_methods[name].body]) || []
            result
          end

          # Reverse Cpp.method_name to recover the Ruby form. Mirrors
          # ClassEmitter.cpp_name_to_ruby — kept here as a convenience
          # for emitter.rb's internal callers (couldn't reuse directly
          # because of module-nesting reach). Keep the two in sync.
          def cpp_name_to_ruby(cpp)
            inv = Cpp::OP_NAMES.invert
            return inv[cpp].to_s if inv.key?(cpp)
            s = cpp.to_s
            if s.start_with?('mm_')
              body = s[3..]
              return "#{body[0..-3]}?" if body.end_with?('_q')
              return "#{body[0..-6]}!" if body.end_with?('_bang')
              return "#{body[0..-4]}=" if body.end_with?('_eq')
              return body
            end
            return s[2..] if s.start_with?('m_')
            s
          end

          # Walk every emitted body looking for ConstantPath nodes whose
          # parent is a runtime expression (`self.class::X`, `obj.foo::X`).
          # Each such `X` needs a `c_X` virtual on BasicObject + an
          # override on every eigenclass that has X in its constants
          # table (or inherits one). Statically-resolvable paths
          # (`Foo::Bar`) keep their cheap `k_Foo_Bar()` accessor.
          # For each eigenclass, look at its host class's full inherited
          # constant set (walking ancestors_list); for each constant
          # whose name is in the dynamic constant surface, append a
          # c_<NAME>() override that returns the value. Constants not
          # in the surface stay where they are (the cheap k_<flat>()
          # accessor handles statically-resolvable Foo::CONST).
          def decorate_eigenclasses_with_const_overrides(host_classes, eigenclasses)
            return if @const_surface.empty?
            top = @top_level_scope.constants_table || {}
            host_by_eigen = {}
            eigenclasses.each do |eigen|
              host_name = eigen.name.sub(/#{Regexp.escape(Reachability::EIG_SUFFIX)}\z/, '')
              host_by_eigen[eigen] = top[host_name.to_sym] || @user_classes[host_name.to_sym]
            end
            eigenclasses.each do |eigen|
              host = host_by_eigen[eigen]
              next unless host.is_a?(Vm::ModuleObject)
              consts = collect_inherited_constants(host)
              eigen.overrides ||= {}
              @const_surface.each do |name|
                next unless consts.key?(name)
                cpp_name = "c_#{name}"
                next if eigen.overrides.key?(cpp_name)  # explicit override wins
                val = consts[name]
                expr =
                  begin
                    @cpp.emit_vm_value(val)
                  rescue Cpp::EmissionError
                    nil
                  end
                next unless expr  # unrenderable constant — fall through to constant_missing
                eigen.overrides[cpp_name] = { params: [], body: "return #{expr};" }
                # Stage 4 of the layouts.hpp split: this auto-stub
                # body is `return (&Foo_CLASS);` (or similar) when
                # val is a class. Record the class ref against the
                # eigenclass's flat name so the per-class .cpp emit
                # picks up the corresponding `#include "class/Foo_eig.hpp"`.
                if val.is_a?(Vm::ModuleObject) && val.full_name
                  ref_flat = Reachability.flat_name(val)
                  @host_class_refs[eigen.name.to_sym] << ref_flat
                end
              end
            end
          end

          # Walk ancestors_list to compute the full inherited constants
          # set for a class. Inner constants override outer ones (i.e.
          # the host's own def wins over an inherited one).
          def collect_inherited_constants(cls)
            seen = {}
            ancestors = cls.ancestors_list rescue [cls]
            # Walk from outermost inward so inner overrides outer.
            ancestors.reverse.each do |a|
              (a.constants_table || {}).each { |name, val| seen[name] = val }
            end
            seen
          end

          def collect_dynamic_constant_surface
            names = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::ConstantPath) && node.parent_node
                # Include every ConstantPath last-segment, regardless
                # of whether the parent is statically resolvable. The
                # static-resolution path can fall back to dynamic c_X
                # dispatch when a constant doesn't resolve at AOT
                # (e.g. `M::UNDEFINED` should reach const_missing at
                # runtime), so the slot needs to exist on the
                # eigenclass either way.
                names << node.name.to_sym
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            walk_method = ->(m) {
              method_walkable_roots(m).each { |r| walk.call(r) }
            }
            user_methods.each_value { |m| walk_method.call(m) }
            @user_classes.each_value do |cls|
              class_methods(cls).each_value { |m| walk_method.call(m) }
              eigenclass_methods(cls).each_value { |m| walk_method.call(m) }
            end
            top = @top_level_scope.constants_table || {}
            Runtime::ALL_CLASSES.each do |universe_klass|
              cls = top[universe_klass.name.to_sym]
              next unless cls.is_a?(Vm::ModuleObject)
              class_methods(cls).each_value { |m| walk_method.call(m) }
              eigenclass_methods(cls).each_value { |m| walk_method.call(m) }
            end
            walk.call(@execute_block) if @execute_block
            names
          end

          # All walkable AST roots for a Vm::Method: body + each
          # optional-param default expression (`def f(x = expr)` —
          # `expr` is its own AST tree, parked in optional_params,
          # not the method body) + each optional kw-param default.
          # Walking only `m.body` misses constant references in
          # those defaults, which would either prune away the
          # referenced class (Reachability) or fail to declare a
          # `c_X` slot (dynamic-constant surface).
          def method_walkable_roots(m)
            return [] unless m.is_a?(Vm::Method)
            roots = []
            roots << m.body if m.body
            (m.optional_params || []).each do |(_n, default)|
              roots << default if default.is_a?(Ast::Node)
            end
            (m.optional_kw_params || []).each do |(_n, default)|
              roots << default if default.is_a?(Ast::Node)
            end
            roots
          end

          # Mirror of Cpp.static_constant_parent? — emitter-side; kept
          # close to collect_dynamic_constant_surface so the surface
          # collector and the lowering decision can't drift.
          def static_constant_parent?(parent)
            parent.is_a?(Ast::ConstantRead) ||
              parent.is_a?(Ast::ConstantPath) ||
              parent.is_a?(Ast::RootNamespaceNode)
          end

          # Build RubyClass instances from each user Vm::ClassObject.
          # Class methods (def self.X, from cls.eigenclass.methods_table)
          # land in `eigenclass_overrides` — Runtime.eigenclass_for picks
          # them up when generating the paired eigenclass.
          def build_user_class_defs
            @user_classes.map { |name, cls|
              # Strict-emit for actually-user user classes (not core/4.0/
              # or vendor/ classes which are reachable-by-definition but
              # rarely on any call path). source_location of the first
              # method tells us where the class is from. A class with no
              # methods stays non-strict by default.
              with_maybe_strict(user_source?(class_source_location(cls))) do
                build_user_class_def(name, cls)
              end
            }
          end

          # Take any method's source_location as a proxy for where the
          # class was defined. Returns "file:line" or nil.
          def class_source_location(cls)
            (cls.methods_table || {}).each_value do |m|
              loc = m.source_location if m.is_a?(Vm::Method)
              return loc if loc
            end
            nil
          end

          def with_maybe_strict(strict)
            return yield unless strict
            with_strict_emit { yield }
          end

          # Toggle strict_emit on for the duration of yield; restore.

          # Toggle strict_emit on for the duration of yield; restore.
          # Only the program path (execute_block + top-level user
          # methods) compiles under strict — emission gaps in core/4.0/
          # or vendor classes that aren't on the call path stay graceful
          # since the right answer for those is reachability pruning,
          # not preemptive aborts.
          def with_strict_emit
            prev = @strict_emit
            @strict_emit = true
            yield
          ensure
            @strict_emit = prev
          end

          # Vm wrapper classes (Vm::StringObject, Vm::FloatObject,
          # Vm::IntegerObject) box a runtime primitive in `iv_raw`.
          # Native Hash's Hasher/KeyEq use the C++ vtable hooks
          # `m_hash_value` / `op_eq_q` to bucket and match keys; without
          # these overrides, two wrappers with content-equal `iv_raw`
          # but different identities hash to different buckets and
          # compare unequal — Hash["a" => 1]["a"] returns nil.
          # Delegate both hooks to `iv_raw` so wrapper-keyed Hashes
          # behave identically to primitive-keyed ones at runtime.
          def value_eq_wrapper_members(cls_name)
            [
              "std::size_t m_hash_value() const override { return iv_raw ? iv_raw->m_hash_value() : 0; }",
              "BO* op_eq_q(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance()) override {",
              "  if (args->data.empty()) return false_instance();",
              "  if (this == args->data[0]) return true_instance();",
              "  BO* _other = args->data[0];",
              "  if (typeid(*_other) != typeid(#{cls_name})) return false_instance();",
              "  auto* o = static_cast<#{cls_name}*>(_other);",
              "  if (!iv_raw || !o->iv_raw) return false_instance();",
              "  return iv_raw->op_eq_q(univ, new Array({o->iv_raw}));",
              "}",
            ]
          end

          VALUE_EQ_WRAPPER_CLASSES = %i[
            Frozone_Vm_StringObject
            Frozone_Vm_FloatObject
            Frozone_Vm_IntegerObject
          ].freeze

          # For user classes that define `hash` directly in Ruby, emit an
          # `m_hash_value` override that dispatches the Ruby method and
          # unboxes the Integer result. Without it, native Hash's Hasher
          # uses BasicObject's identity default — two value-equal instances
          # (with matching `def hash` / `def ==`) hash to different buckets
          # and look up as distinct keys. KeyEq already routes through the
          # Ruby `==` (op_eq_q vtable slot) so user-defined `==` works once
          # the keys land in the same bucket.
          def user_hash_delegate_members(cls_name)
            [
              "std::size_t m_hash_value() const override {",
              "  if (auto* _i = BO::try_cast<Integer>(const_cast<#{cls_name}*>(this)->m_hash(univ))) return static_cast<std::size_t>(_i->raw_);",
              "  return reinterpret_cast<std::size_t>(this);",
              "}",
            ]
          end

          # Self-host: user-defined guest classes (e.g. interpreter user code
          # subclassing `Object`) live as runtime `Frozone_Vm_ClassObject`s;
          # their `hash` / `eql?` bodies sit in the class_object method
          # table, not in any C++ vtable. When such an instance flows into
          # the native Hash as a key, Hasher would otherwise use the
          # identity default. Override `m_hash_value` on the universal
          # guest base `Frozone_Vm_ObjectObject` to dispatch `:hash`
          # through the full Ruby protocol (m_dispatch handles ancestor
          # walking, refinements, method_missing) and unbox the result.
          # Specialized Vm wrapper subclasses (Vm::StringObject etc.)
          # already override `m_hash_value` with a fast path that takes
          # precedence; this override only fires for classes that don't.
          OBJECTOBJECT_RUNTIME_DISPATCH = :Frozone_Vm_ObjectObject

          # Vm singleton/interned classes — identity hash is canonical
          # because there's at most one instance per value. Override
          # `m_hash_value` to identity so they don't pay the dispatch
          # cost from OBJECTOBJECT_RUNTIME_DISPATCH on every Hash key
          # lookup (Symbol-keyed Hashes are the hot path in the
          # interpreter — kwargs, instance variables, locals).
          IDENTITY_HASH_VM_CLASSES = %i[
            Frozone_Vm_SymbolObject
            Frozone_Vm_NilObject
            Frozone_Vm_TrueObject
            Frozone_Vm_FalseObject
          ].freeze

          def identity_hash_members
            ["std::size_t m_hash_value() const override { return reinterpret_cast<std::size_t>(this); }"]
          end

          def runtime_dispatch_hash_members(cls_name)
            # Header-inline-safe: use g_fiber_storage() (returns Hash*,
            # always complete) rather than `&Fiber_CLASS` (Fiber_eigenclass
            # is forward-declared at this point). The dispatched method
            # body needs a real Vm Context — m_invoke / inner dispatches
            # crash with `nil.frame` if context is nil.
            #
            # Lookup form: when m_lookup_instance_method is NA-eligible
            # (FROZONE_NATURAL_ARGS=1) we emit the direct 1-arg NA call
            # — passes the Symbol* without allocating an Array wrapper.
            # Otherwise we fall back to the 3-arg universal form. The
            # call routes the same place either way; NA just skips the
            # trampoline + Array alloc on the hot path.
            lim_na = @natural_arity_names[:lookup_instance_method]
            lim_call = ->(sym_lit) do
              if lim_na
                %|_self->m_lookup_instance_method(intern("#{sym_lit}"))|
              else
                %|_self->m_lookup_instance_method(univ, new Array({intern("#{sym_lit}")}), &EMPTY_KWARGS, nil_instance())|
              end
            end
            [
              "std::size_t m_hash_value() const override {",
              "  auto* _self = const_cast<#{cls_name}*>(this);",
              "  if (!_self->iv_class_object) return reinterpret_cast<std::size_t>(_self);",
              "  // Probe method table before dispatching — many built-in classes",
              "  // (Class, BasicObject, the Vm internals) have hash only at the",
              "  // C++ vtable layer. Dispatching :hash there would fall through",
              "  // to method_missing and BUG. Identity is the right default.",
              "  BO* _m = #{lim_call.call('hash')};",
              "  if (!_m || _m == nil_instance() || _m == k_Frozone_Vm_ModuleObject_UNDEF_SENTINEL()) {",
              "    return reinterpret_cast<std::size_t>(_self);",
              "  }",
              "  BO* _ctx = g_fiber_storage()->op_aref(univ, new Array({intern(\"context\")}));",
              "  if (!_ctx || _ctx == nil_instance()) return reinterpret_cast<std::size_t>(_self);",
              "  BO* _r = _self->m_dispatch(univ,",
              "    new Array({_ctx, intern(\"hash\"), &EMPTY_ARGS, static_cast<BO*>(&EMPTY_KWARGS), nil_instance()}),",
              "    &EMPTY_KWARGS, nil_instance());",
              "  // Re-dispatch m_hash_value on the result: Vm::IntegerObject (the",
              "  // typical return) overrides m_hash_value to delegate to iv_raw",
              "  // (runtime Integer, value-based hash). Avoids dynamic_cast to",
              "  // forward-declared Vm types in this inline body.",
              "  return _r ? _r->m_hash_value() : reinterpret_cast<std::size_t>(_self);",
              "}",
              # KeyEq on native Hash calls `a->op_eq_q(&tmp_with_b)` via the C++
              # vtable. For guest user instances, op_eq_q inherits BasicObject's
              # identity default — user-defined `def ==` lives in the class_object
              # method table and isn't reflected in the vtable. Dispatch `:==` so
              # the user's equality wins. Vm::True/False/NilObject are fused
              # with the runtime singletons, so `truthy()` covers both sides
              # without needing those Vm classes complete here.
              "BO* op_eq_q(UnivTag, Array* args = &EMPTY_ARGS, Hash* kwargs = &EMPTY_KWARGS, BO* block = nil_instance()) override {",
              "  if (args->data.empty()) return false_instance();",
              "  BO* _other = args->data[0];",
              "  if (this == _other) return true_instance();",
              "  auto* _self = const_cast<#{cls_name}*>(this);",
              "  if (!_self->iv_class_object) return false_instance();",
              "  // Probe the class_object method table first. Many built-in classes",
              "  // (BasicObject, Class itself) don't define `==` as a Ruby method —",
              "  // it only exists at the C++ vtable layer. Dispatching `:==` there",
              "  // would fall through to method_missing and BUG. Identity check has",
              "  // already returned true if pointers match; otherwise default to",
              "  // false unless a Ruby `==` is registered.",
              "  BO* _m = #{lim_call.call('==')};",
              "  if (!_m || _m == nil_instance() || _m == k_Frozone_Vm_ModuleObject_UNDEF_SENTINEL()) {",
              "    return false_instance();",
              "  }",
              "  BO* _ctx = g_fiber_storage()->op_aref(univ, new Array({intern(\"context\")}));",
              "  if (!_ctx || _ctx == nil_instance()) return false_instance();",
              "  Array* _outer = new Array({_other});",
              "  BO* _r = _self->m_dispatch(univ,",
              "    new Array({_ctx, intern(\"==\"), static_cast<BO*>(_outer), static_cast<BO*>(&EMPTY_KWARGS), nil_instance()}),",
              "    &EMPTY_KWARGS, nil_instance());",
              "  return truthy(_r) ? true_instance() : false_instance();",
              "}",
            ]
          end

          def class_defines_method?(cls, name)
            direct_methods(cls).key?(name)
          rescue StandardError
            false
          end

          def build_user_class_def(name, cls)
            # `Struct.new(:foo, :bar)` subclasses store their accessors
            # as define_method-generated Procs over closure variables —
            # the bodies aren't compilable as standalone methods. Synth
            # them mechanically: per-member ivar + getter + setter +
            # positional-arg initialize. Mirrors what the Crystal /
            # legacy-cpp backends do via emit_struct_subclass.
            return build_struct_subclass_def(name, cls) if struct_subclass?(cls)

            ivars = collect_ivars(cls)
            # Drop ivars already declared in the C++ parent chain.
            # collect_ivars walks `class_methods(cls)` which uses
            # ModuleFlattening — that includes parent methods, so a
            # derived class would re-collect every parent ivar
            # referenced by inherited methods. Re-declaring shadows
            # the base-class field: writes from the parent's m_X
            # body land in the base field; reads from a method
            # emitted on the derived class read the (uninitialised
            # nil) derived field. Concretely, Map sets iv_expression
            # in m_initialize; Map::Operator's m_expression returned
            # its own (nil) iv_expression. Drop those duplicates.
            parent_ivars = collect_parent_ivars(cls)
            ivars = ivars.reject { |iv| parent_ivars.include?(iv) }
            eigen_ivars = collect_eigenclass_ivars(cls)
            # Pure modules (not classes) flag is_module so their
            # eigenclass inherits from Module (matching MRI's
            # `mod.class == Module`).
            is_module = cls.is_a?(Vm::ModuleObject) && !cls.is_a?(Vm::ClassObject)
            Runtime::RubyClass.new(
              name: name.to_s,
              parent: parent_name_for(cls),
              is_module: is_module,
              ivars: ivars.map { |iv| "BO* iv_#{iv} = nil_instance();" },
              members: [
                %(const char* ruby_class_name() const override { return "#{name}"; }),
                *(IDENTITY_HASH_VM_CLASSES.include?(name) ? identity_hash_members : []),
                *(VALUE_EQ_WRAPPER_CLASSES.include?(name) ? value_eq_wrapper_members(name.to_s) : []),
                *(name == OBJECTOBJECT_RUNTIME_DISPATCH ? runtime_dispatch_hash_members(name.to_s) : []),
                *(!IDENTITY_HASH_VM_CLASSES.include?(name) && !VALUE_EQ_WRAPPER_CLASSES.include?(name) && name != OBJECTOBJECT_RUNTIME_DISPATCH && class_defines_method?(cls, :hash) ? user_hash_delegate_members(name.to_s) : []),
              ],
              # No special ctor — `initialize` becomes a regular
              # `m_initialize` override; eigenclass auto-emits `m_new`
              # that does `new X(); m_initialize(...); return obj;`.
              overrides: build_chained_overrides(name.to_s, class_method_chains(cls), host_class: cls),
              eigenclass_overrides: eigenclass_methods(cls).each_with_object({}) { |(mname, m), h|
                cpp_name = Cpp.method_name(mname)
                next if ENV['FROZONE_BOX_NO_PRUNE'] == '1' && WIDENING_BLACKLIST.include?(mname)
                next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || @call_surface.key?(cpp_name)
                spec = build_override(m, storage_name: mname)
                h[cpp_name] = spec if spec
              },
              eigenclass_ivars: eigen_ivars,
            )
          end

          # Walk a chain map and emit one override per (origin, method)
          # pair: head of each chain → `m_X`, rest → `sm_X__from_<Origin>`.
          # Each gets a super_context so Ast::Super inside the body
          # resolves to the next slot. EmissionError on any one body
          # drops just that slot.
          def build_chained_overrides(host_name, chains, host_class: nil)
            result = {}
            # Hand-coded ancestor methods (m_class, m_send, mm_is_a_q, …)
            # have load-bearing C++ implementations we must NOT shadow
            # with the Ruby-level def from Kernel/Object. E.g.
            # Kernel#class lowers to `this->m_class(univ)`; if a user class
            # picks that up via chain-flattening as its m_class
            # override, every dispatch infinitely recurses. The fix:
            # for any hand-coded universe-ancestor name where the
            # chain's head ISN'T the user's own `def` (origin != :self),
            # drop the chain entirely — C++ inheritance picks up the
            # hand-coded ancestor.
            hand_coded = (Runtime::ALL_CLASSES.flat_map { |k| k.hand_coded_method_names || [] }).to_set
            chains.each do |mname, entries|
              cpp_name = Cpp.method_name(mname)
              # Method-level reachability gate: skip the whole chain
              # if the method name isn't called from any reachable
              # body. The unused-method bloat (~1200 unused virtual
              # overrides per class pre-pruning) was driving cpp size.
              next if ENV['FROZONE_BOX_NO_PRUNE'] == '1' && WIDENING_BLACKLIST.include?(mname)
              next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || @call_surface&.key?(cpp_name)
              # Stage 3: drop the chain when no self-receiver call site
              # can dispatch through this host (and surface isn't wide).
              next unless ENV['FROZONE_BOX_NO_PRUNE'] == '1' || method_keepable_for_class?(cpp_name, host_class)
              if hand_coded.include?(cpp_name)
                head_origin, _ = entries.first
                next if head_origin != :self
              end
              # Tail-pruning: only emit the next sm_X__from_Y slot when
              # the previous body actually calls `super`. Stops emission
              # the moment a body returns without super-ing — the head
              # not calling super at all (the common case) collapses the
              # whole chain to a single override.
              prev_needs_super = true
              entries.each_with_index do |(origin, method), idx|
                break if idx.positive? && !prev_needs_super
                # Class-origin entries don't get sm_X slots on the host
                # — super lowers them to qualified `this->Parent::m_X`,
                # using C++ inheritance directly. Module-origin entries
                # (and the head, idx=0) DO get slots emitted here.
                if idx.positive? && origin.is_a?(Vm::ClassObject)
                  prev_needs_super = method_calls_super?(method)
                  next
                end
                cpp_name = idx.zero? ? Cpp.method_name(mname) : Cpp.shadowed_method_name(mname, origin)
                ctx = {
                  host_name: host_name, method_name: mname, origin_index: idx, chain: entries,
                  method_params: ((method.required_params || []) + (method.optional_params || []).map(&:first)).map { |p| MethodEmitter.local_cpp_name(p) },
                  # kw_params is set in from_super; here we only need
                  # positional. Super forwarding reads kw locals from
                  # the natural-arity sig in the survey table directly.
                }
                spec =
                  begin
                    build_override(method, super_ctx: ctx, storage_name: mname)
                  rescue Cpp::EmissionError => e
                    raise Cpp::EmissionError, "while compiling #{host_name}##{mname} (origin=#{origin}): #{e.message}"
                  end
                # build_override returns nil for graceful-skipped bodies.
                # For sm_X__from_<...> slots specifically, the slot is
                # referenced by an enclosing method's `super` call, so
                # we MUST emit something or the C++ won't link. Stub it
                # with a method_missing redirect.
                if spec.nil? && idx.positive?
                  spec = {
                    params: [],
                    body: %|return mm_dispatch(this, args, kwargs, block, "#{mname}");|,
                  }
                end
                result[cpp_name] = spec if spec
                prev_needs_super = method_calls_super?(method)
              end
            end
            result
          end

          def struct_subclass?(cls)
            return false unless cls.is_a?(Vm::ClassObject)
            return false if cls.name == :Struct  # Struct itself isn't a subclass
            c = cls.superclass
            while c && c.is_a?(Vm::ClassObject)
              return true if c.name == :Struct
              c = c.superclass
            end
            false
          end

          def struct_members(cls)
            members_obj = cls.get_ivar(:@members)
            return [] unless members_obj.respond_to?(:raw)
            members_obj.raw.map { |sym_obj| sym_obj.respond_to?(:raw) ? sym_obj.raw : sym_obj.to_sym }
          end

          # Build a Struct subclass with synthesized ivars + accessors +
          # positional-arg initialize. The Ruby-source methods (closure-
          # based, define_method-generated) are bypassed entirely.
          def build_struct_subclass_def(name, cls)
            members = struct_members(cls)
            overrides = {}
            members.each do |m|
              overrides[Cpp.method_name(m)] = {
                params: [],
                body: "return this->iv_#{m};",
              }
              overrides[Cpp.method_name(:"#{m}=")] = {
                params: ["BO* v"],
                body: "this->iv_#{m} = v; return v;",
              }
            end
            init_body = members.each_with_index.map { |m, i|
              "if (args->data.size() > #{i}) this->iv_#{m} = args->data[#{i}];"
            }.join(" ")
            overrides["m_initialize"] = {
              params: [],
              body: "#{init_body} return this;",
            }
            Runtime::RubyClass.new(
              name: name.to_s,
              parent: parent_name_for(cls),
              ivars: members.map { |m| "BO* iv_#{m} = nil_instance();" },
              members: [%(const char* ruby_class_name() const override { return "#{name}"; })],
              overrides: overrides,
              eigenclass_overrides: {},
              eigenclass_ivars: collect_eigenclass_ivars(cls),
            )
          end

          # `def self.X` bodies referencing `@y` need iv_y declared on
          # the eigenclass struct (singleton ivars on the metaclass).
          # Also scans the ClassObject's actual ivar table — `self.X =`
          # at class-body level sets ivars on the class object itself
          # (which we render as the eigenclass singleton); without
          # this, runtime-set ivars like `@_lex_actions` (via
          # `attr_accessor` setter at class-body level) wouldn't
          # appear in the emitted struct.
          def collect_eigenclass_ivars(cls)
            eigen = cls.eigenclass rescue nil
            return [] unless eigen
            ivars = []
            seen = Set.new
            add = ->(name) {
              s = name.to_s.delete_prefix('@')
              unless seen.include?(s)
                seen << s
                ivars << s
              end
            }
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::InstanceVariableWrite) || node.is_a?(Ast::InstanceVariableRead)
                add.call(node.name)
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            eigenclass_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            (cls.instance_variables_hash || {}).each_key { |k| add.call(k) }
            ivars
          end

          # Walk class.eigenclass.methods_table for `def self.X` entries.
          # Same closed-world policy as class_methods — emit all, let
          # graceful degradation drop the ones we can't compile.
          # Filter to methods *defined* on this eigenclass: Frozone Vm
          # copies inherited module methods (Class#new, Class#allocate,
          # …) into every eigenclass's methods_table, which would
          # shadow the auto-emit `m_new`/`m_allocate` with the
          # abort-stub for `:class_new` / `:class_allocate`. The
          # auto-emit (`overrides["m_new"] ||= …`) only kicks in when
          # the slot is empty, so we must not overlay the inherited
          # copies. Same fix as direct_methods.
          def eigenclass_methods(cls)
            eigen = cls.eigenclass rescue nil
            return {} unless eigen
            top_level_methods = (@top_level_scope.methods_table || {})
            (eigen.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method)
              next false if top_level_methods[name] == m
              # `def self.foo` adds to eigen.methods_table but its
              # lexical scopes.last is the host class (`Fiber`), not
              # the eigenclass. `class << self; def foo; end; end`
              # gives scopes.last == eigen. Both are genuine
              # singleton-method definitions; accept either. Methods
              # copied in by Frozone Vm from parent classes (Class#new,
              # Module#name, …) have scopes.last that's neither.
              defining_scope = m.scopes.last rescue nil
              next true if defining_scope.nil?
              defining_scope.equal?(cls) || defining_scope.equal?(eigen)
            end
          end

          # Walk the C++ struct parent chain of a runtime RubyClass and
          # return the set of ivar names declared on any ancestor —
          # used by overlay_universe_methods to suppress
          # extra_ivars that would shadow an inherited member. Only
          # parents within the user-class set contribute (Object /
          # BasicObject / hand-coded universe ivars are already in
          # `members:` and caught by the existing ivar regex).
          def inherited_ivar_names(klass)
            seen = Set.new
            parent_name = klass.parent
            while parent_name
              # Universe parent (Object/BasicObject/Module/...) — slots
              # declared via `members:` show up as `iv_X` lines we can
              # scan. Required since de-fusion put iv_class_object etc.
              # on Object, and any subclass would otherwise re-declare
              # and shadow them.
              ru_parent = UNIVERSE_BY_NAME[parent_name.to_s]
              if ru_parent
                runtime_member_ivar_names(ru_parent).each { |iv| seen << iv }
                parent_name = ru_parent.parent
                next
              end
              user_parent = @user_classes[parent_name.to_sym]
              break unless user_parent
              collect_ivars(user_parent).each { |iv| seen << iv }
              parent_name = user_parent.respond_to?(:superclass) &&
                            user_parent.superclass &&
                            user_parent.superclass.respond_to?(:full_name) ?
                              Reachability.flatten(user_parent.superclass.full_name) :
                              nil
            end
            seen
          end

          UNIVERSE_BY_NAME = Runtime::ALL_CLASSES.each_with_object({}) { |c, h| h[c.name.to_s] = c }.freeze

          def runtime_member_ivar_names(ru_class)
            (ru_class.members || []).filter_map { |line| line[/\biv_([A-Za-z_][A-Za-z_0-9]*)\b/, 1] }
          end

          # Slots placed on Object's struct (universal — every Ruby
          # object carries them). Cached so collect_parent_ivars /
          # inherited_ivar_names can dedup without re-scanning
          # Object.members each call.
          OBJECT_UNIVERSAL_IVARS = (UNIVERSE_BY_NAME["Object"].members || [])
            .filter_map { |line| line[/\biv_([A-Za-z_][A-Za-z_0-9]*)\b/, 1] }
            .freeze

          # Collect ivars from the cls's parent chain (cls's
          # superclass, its superclass, ...). Used to filter out
          # already-declared ivars when emitting a derived struct,
          # avoiding C++ field shadowing.
          def collect_parent_ivars(cls)
            # Universal Object slots: every Ruby object gets these via
            # Object's struct in the gen, so any subclass that mentions
            # them via collect_ivars must NOT redeclare.
            seen = Set.new(OBJECT_UNIVERSAL_IVARS)
            sc = cls.respond_to?(:superclass) ? cls.superclass : nil
            while sc && sc.respond_to?(:full_name) && sc.full_name &&
                  sc.full_name != :Object
              flat = Reachability.flat_name(sc)
              parent_cls = @user_classes[flat]
              if parent_cls
                collect_ivars(parent_cls).each { |iv| seen << iv }
              end
              sc = sc.respond_to?(:superclass) ? sc.superclass : nil
            end
            seen
          end

          # Walk user-source methods for InstanceVariableWrite/Read —
          # those tell us which ivars to declare.
          def collect_ivars(cls)
            ivars = []
            seen = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::InstanceVariableWrite) || node.is_a?(Ast::InstanceVariableRead)
                stripped = node.name.to_s.delete_prefix('@')
                unless seen.include?(stripped)
                  seen << stripped
                  ivars << stripped
                end
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            class_methods(cls).each_value { |m| walk.call(m.body) if m.body }
            ivars
          end

          # Set of Vm class objects that are LEAVES in the closed-world
          # class hierarchy (no other class names them as direct
          # superclass). Modules (Vm::ModuleObject without ClassObject)
          # are excluded — they have no instances, so typeid checks
          # against them would never match anything `*this` could be.
          def compute_leaf_classes
            return @leaf_classes if defined?(@leaf_classes)
            top = @top_level_scope.constants_table || {}
            classes = []
            Runtime::ALL_CLASSES.each do |uk|
              c = top[uk.name.to_sym]
              classes << c if c.is_a?(Vm::ClassObject)
            end
            @user_classes.each_value do |c|
              classes << c if c.is_a?(Vm::ClassObject)
            end
            parent_set = Set.new
            classes.each { |c| parent_set << c.superclass if c.superclass.is_a?(Vm::ClassObject) }
            # Runtime::ALL_CLASSES contains C++-only RubyClass entries
            # (Proc0/Proc1/Proc2 etc.) that aren't Vm::ClassObjects, so
            # their `parent` string points at a class that IS a Vm one
            # (e.g. "Proc"). Without this pass, Proc is incorrectly
            # marked as a leaf and the leaf-dispatch `final` emission
            # devirtualises `static_cast<Proc*>(...)->m_call(...)` to
            # base `Proc::m_call`, which reads the base-class `fn_`
            # field that's left default-constructed on Proc1/Proc2
            # instances (each ProcN owns its own arity-typed `fnN_`).
            Runtime::ALL_CLASSES.each do |uk|
              next unless uk.parent
              pc = top[uk.parent.to_sym]
              parent_set << pc if pc.is_a?(Vm::ClassObject)
            end
            @leaf_classes = classes.reject { |c| parent_set.include?(c) }.to_set
          end

          # Leaf-dispatch eligibility: ruby_name → Array<Vm::ClassObject>
          # for names whose defining classes are ALL leaves AND total
          # ≤ max_k. Used by class_emitter to swap the universal-sig
          # slot for a K-way typeid gateway (Phase A: K=1, Phase B: K≤4).
          #
          # Composes additively with natural-args (per-arity / multi-arity
          # / kw_unset overloads on the leaf are untouched — gateway only
          # replaces BasicObject's universal-sig slot; static-arity calls
          # bypass the gateway via direct overload resolution).
          #
          # Excluded: hand-coded inline methods on BasicObject (universal-
          # sig bodies live in the struct, can't be moved). Names whose
          # defining set includes a non-leaf class (modules included,
          # base classes) are Phase C (deferred).
          def compute_leaf_dispatch_table(agg, exclude: Set.new, max_k: 4)
            leaves = compute_leaf_classes
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              defining = agg.defining_classes(name)
              next if defining.empty? || defining.size > max_k
              next unless defining.all? { |c| leaves.include?(c) }
              h[name] = defining.to_a
            end
          end

          def parent_name_for(cls)
            # Modules have no superclass — emit them as Object subclasses.
            # Their struct is a marker (no instances ever allocated); the
            # eigenclass holds the singleton methods (def self.X).
            return "Object" unless cls.is_a?(Vm::ClassObject)
            sc = cls.superclass
            return "Object" unless sc
            return "Object" if sc.name == :Object || sc.name.nil?
            # Nested classes (Parser::Lexer) need the flattened parent
            # name (`Parser_Lexer`) so the emitted struct inherits from
            # the right type — leaf-name alone collides across nesting.
            Reachability.flatten(sc.full_name)
          end

          # Build a ctor spec for a user class. Required params land as
          # `BO* x`; optional params get C++ default-arg syntax
          # (`BO* x = <default_expr>`). Rest/post/kw params are
          # not yet supported in ctors — raise EmissionError so the
          # whole class falls through to a default ctor (callsites that
          # try to instantiate it with args will then fail to compile,
          # which is the right loud signal).
          # Build an override spec for a user method using unpack_params
          # (so rest/block handling matches MethodEmitter). Empty params
          # field means class_emitter doesn't double-emit unpack lines.
          # EmissionError → nil so caller can drop the entry; the slot
          # falls through to BasicObject's method_missing stub at runtime.
          # build_override variant for natural-arity-eligible names.
          # Spec has natural-arity sig (one BO* per required
          # param) and a body that uses the named params directly —
          # no array_at unpack. Wraps the body in the same try/catch
          # ReturnException as build_override so return-from-block
          # semantics work identically.
          #
          # If the def's shape doesn't fit the eligibility contract
          # (caller-side eligibility said natural-arity but this def
          # has opts / rest / etc.) we raise EmissionError so caller
          # falls through to its abort-stub path, keeping the slot
          # signature consistent with BasicObject's natural-arity
          # default decl.
          def build_natural_arity_override(method, sig)
            required = method.required_params || []
            req_kw = (method.required_kw_params || []).map(&:to_sym).sort
            if required.length != sig.arity_req ||
               !(method.optional_params || []).empty? ||
               !(method.post_params || []).empty? ||
               method.rest_param ||
               method.kw_rest_param ||
               !(method.optional_kw_params || []).empty? ||
               req_kw != sig.required_kw_names ||
               (!sig.has_block && method.block_param)
              raise Cpp::EmissionError, "natural-arity shape mismatch for :#{method.name}: def doesn't fit #{sig}"
            end
            captured = method.body ? MethodEmitter.collect_method_captured(method) : Set.new
            # NA-with-block slot has `Proc* block = nullptr` — set the
            # flag so block_given? lowers as `_block != nullptr` for
            # the duration of body emission.
            prev_block_nullable = @cpp.block_is_nullable
            @cpp.block_is_nullable = sig.has_block
            needs_frame = false
            body = @cpp.with_captured_locals(captured) do
              capture do
                needs_frame = @cpp.with_frame_id_tracking do
                locals = Set.new
                # Re-declare each natural-arity param as a body local
                # via decl_local_line — heap-cell form when captured,
                # stack local otherwise. The signature param uses an
                # anonymous name (_arg<i> / _kw_<name>) so the local
                # binding can shadow it with the right cpp_name +
                # captured-aware storage class. Mirrors unpack_params'
                # treatment for universal-sig methods.
                required.each_with_index do |p, i|
                  line MethodEmitter.decl_local_line(self, p, "_arg#{i}")
                  locals << p.to_s
                end
                sig.required_kw_names.each do |kn|
                  line MethodEmitter.decl_local_line(self, kn, "_kw_#{kn}")
                  locals << kn.to_s
                end
                if sig.has_block
                  # Note: `Proc* _block = block;` is emitted by
                  # write_override_def's NA-with-block prelude
                  # (class_emitter.rb) — no need to re-declare here
                  # in the body. Inner duplicate was previously hidden
                  # by the enclosing try{...} scope; with the frame
                  # elision the body and prelude share a scope.
                  user_block = MethodEmitter.user_block_name(method)
                  if user_block
                    # Keep user_block typed as Proc* so `if block`
                    # resolves to truthy(Proc*) — nullptr check only.
                    # Erasing to BO* would silently absorb
                    # the nullptr-as-truthy bug. See method_emitter.rb
                    # for the same change in the parallel NA-with-block
                    # emission path.
                    cpp = MethodEmitter.local_cpp_name(user_block)
                    if @cpp.captured?(user_block)
                      line "BO** #{cpp} = gc_box<BO*>(block ? static_cast<BO*>(block) : nil_instance());"
                    else
                      line "Proc* #{cpp} = block;"
                    end
                    locals << user_block
                  end
                end
                seen_writes = MethodEmitter.collect_local_writes(method.body)
                ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                  s = loc.to_s
                  next if s.empty? || locals.include?(s)
                  line MethodEmitter.decl_local_line(self, s, "nil_instance()")
                  locals << s
                end
                ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
                end
              end
            end
            @cpp.block_is_nullable = prev_block_nullable
            vis_prologue = MethodEmitter.visibility_prologue_text(
              @visibility_survey, method.name, method.visibility, body: method.body
            )
            # spec[:params] carries only the positional slot decls;
            # write_override_def appends `_kw_<name>` decls from the
            # NaturalAritySig directly (so the spec stays the same
            # shape as universal-sig specs — body's local bindings
            # via decl_local_line handle the kw mapping).
            {
              params: required.each_with_index.map { |_, i| "BO* _arg#{i}" },
              body: MethodEmitter.body_with_frame_text(body, needs_frame, vis_prologue: vis_prologue),
            }
          end

          # Per-arity entry points for a pure-positional def. For arities
          # the def serves (arity_req..arity_req+opt), emit the body
          # with appropriate default-fill prefix. For other family
          # arities (cross-class divergence — another class defines the
          # name at an arity this def doesn't serve), emit a wrong-args
          # stub so call sites at those arities raise ArgumentError on
          # an instance of this class rather than method_missing.
          def build_multi_arity_override(method, family, storage_name: nil)
            required = method.required_params || []
            optional = method.optional_params || []
            arity_req = required.length
            arity_max = arity_req + optional.length
            if !(method.post_params || []).empty? ||
               method.rest_param ||
               method.kw_rest_param ||
               !(method.required_kw_params || []).empty? ||
               !(method.optional_kw_params || []).empty? ||
               method.block_param
              raise Cpp::EmissionError, "multi-arity requires pure-positional def"
            end
            captured = method.body ? MethodEmitter.collect_method_captured(method) : Set.new
            entries = family.arities.to_a.sort.map do |k|
              if k < arity_req || k > arity_max
                check_call = arity_req == arity_max ?
                  "check_arity_fixed(#{k}, #{arity_req});" :
                  "check_arity_range(#{k}, #{arity_req}, #{arity_max});"
                next({
                  params: (0...k).map { |i| "BO* _arg#{i}" },
                  body: "#{check_call}\nreturn nil_instance();\n",
                })
              end
              bound_opt = k - arity_req
              needs_frame = false
              body = @cpp.with_captured_locals(captured) do
                capture do
                  needs_frame = @cpp.with_frame_id_tracking do
                  locals = Set.new
                  required.each_with_index do |p, i|
                    line MethodEmitter.decl_local_line(self, p, "_arg#{i}")
                    locals << p.to_s
                  end
                  # Caller-bound optionals
                  optional.first(bound_opt).each_with_index do |(p, _), j|
                    idx = arity_req + j
                    line MethodEmitter.decl_local_line(self, p, "_arg#{idx}")
                    locals << p.to_s
                  end
                  # Default-fill the rest, in declaration order — later
                  # defaults can reference earlier ones (def m(a, b=a+1)).
                  optional.drop(bound_opt).each do |(p, default_node)|
                    default_str = default_node ? @cpp.from_expr(default_node, locals) : "nil_instance()"
                    line MethodEmitter.decl_local_line(self, p, default_str)
                    locals << p.to_s
                  end
                  seen_writes = MethodEmitter.collect_local_writes(method.body)
                  ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                    s = loc.to_s
                    next if s.empty? || locals.include?(s)
                    line MethodEmitter.decl_local_line(self, s, "nil_instance()")
                    locals << s
                  end
                  ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
                  end
                end
              end
              ma_vis_prologue = MethodEmitter.visibility_prologue_text(
                @visibility_survey, storage_name || method.name, method.visibility, body: method.body
              )
              {
                params: (0...k).map { |i| "BO* _arg#{i}" },
                body: MethodEmitter.body_with_frame_text(body, needs_frame, vis_prologue: ma_vis_prologue),
              }
            end
            spec = { multi_arity: entries }
            # Class-specific universal-sig override: when this class's
            # arity range is narrower than the family, the family-wide
            # check_arity_range message ("expected 1..3") differs from
            # MRI's class-specific ("expected 1..2"). Emit a per-class
            # universal-sig override that re-runs the arity check with
            # class arities before dispatching into per-arity slots.
            class_arities = (arity_req..arity_max).to_a
            family_arities = family.arities.to_a.sort
            if class_arities != family_arities
              check_call = arity_req == arity_max ?
                "check_arity_fixed(args->data.size(), #{arity_req});" :
                "check_arity_range(args->data.size(), #{arity_req}, #{arity_max});"
              # Use storage_name for the dispatch — aliased methods
              # (alias size length) reach build_multi_arity_override
              # with method.name=:length but get emitted at the alias
              # slot (storage_name=:size). The switch must dispatch
              # back into the slot we're inside, not the original.
              call_cpp_name = Cpp.method_name(storage_name || method.name)
              switch_lines = family_arities.map do |k|
                args_call = (0...k).map { |i| "args->data[#{i}]" }.join(', ')
                "    case #{k}: return this->#{call_cpp_name}(#{args_call});"
              end.join("\n")
              spec[:universal_entry] = {
                params: ["UnivTag", "Array* args", "Hash* kwargs", "BO* /*block*/"],
                body: <<~CPP,
                  if (kwargs != &EMPTY_KWARGS) args = fold_kwargs_into_args_tail(args, kwargs);
                  #{check_call}
                  switch (args->data.size()) {
                  #{switch_lines}
                      default: return nil_instance();  // unreachable: check_arity raises
                  }
                CPP
              }
            end
            spec
          end

          # Kw-bearing override (UNSET path). Single slot signature:
          # required pos → opt pos (UNSET-able) → kws alphabetical.
          # Body declares locals from slot params, default-filling
          # UNSET slots in source order so later defaults can read
          # earlier-bound params.
          def build_kw_unset_override(method, sig)
            required = method.required_params || []
            optional = method.optional_params || []
            opt_kw_pairs = method.optional_kw_params || []
            opt_kw_defaults = opt_kw_pairs.to_h { |p, default| [p.to_sym, default] }
            if !(method.post_params || []).empty? || method.rest_param || method.kw_rest_param || method.block_param
              raise Cpp::EmissionError, "kw-unset requires pure positional+kw def"
            end
            if required.length != sig.arity_req || optional.length != sig.opt
              raise Cpp::EmissionError, "kw-unset shape mismatch for :#{method.name}"
            end
            captured = method.body ? MethodEmitter.collect_method_captured(method) : Set.new
            needs_frame = false
            body = @cpp.with_captured_locals(captured) do
              capture do
                needs_frame = @cpp.with_frame_id_tracking do
                locals = Set.new
                required.each_with_index do |p, i|
                  line MethodEmitter.decl_local_line(self, p, "_arg#{i}")
                  locals << p.to_s
                end
                optional.each_with_index do |(p, default_node), i|
                  slot = "_arg#{sig.arity_req + i}"
                  default_str = default_node ? @cpp.from_expr(default_node, locals) : "nil_instance()"
                  line MethodEmitter.decl_local_line(self, p, "(#{slot} == unset_instance()) ? (#{default_str}) : #{slot}")
                  locals << p.to_s
                end
                sig.all_kw_names.each do |kn|
                  if sig.kw_required?(kn)
                    line MethodEmitter.decl_local_line(self, kn, "_kw_#{kn}")
                  else
                    default_node = opt_kw_defaults[kn]
                    default_str = default_node ? @cpp.from_expr(default_node, locals) : "nil_instance()"
                    line MethodEmitter.decl_local_line(self, kn, "(_kw_#{kn} == unset_instance()) ? (#{default_str}) : _kw_#{kn}")
                  end
                  locals << kn.to_s
                end
                seen_writes = MethodEmitter.collect_local_writes(method.body)
                ((method.locals || []) + seen_writes.to_a).uniq.each do |loc|
                  s = loc.to_s
                  next if s.empty? || locals.include?(s)
                  line MethodEmitter.decl_local_line(self, s, "nil_instance()")
                  locals << s
                end
                ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
                end
              end
            end
            slot_params = (0...sig.arity_req).map { |i| "BO* _arg#{i}" } +
                          (0...sig.opt).map { |i| "BO* _arg#{sig.arity_req + i}" } +
                          sig.all_kw_names.map { |kn| "BO* _kw_#{kn}" }
            ku_vis_prologue = MethodEmitter.visibility_prologue_text(
              @visibility_survey, method.name, method.visibility, body: method.body
            )
            {
              params: slot_params,
              body: MethodEmitter.body_with_frame_text(body, needs_frame, vis_prologue: ku_vis_prologue),
              kw_unset: true,
            }
          end

          def build_override(method, super_ctx: nil, fall_through_on_error: false, storage_name: nil)
            with_method_scope(method) do
              with_super_context(super_ctx) do
                # Eligibility for natural-arity is per-SLOT (the
                # storage Ruby name under which the slot lives on
                # the class), not per-method.name. An aliased method
                # (e.g. `alias modulo %`) is one Vm::Method under
                # multiple storage names — method.name is the
                # original (`:%`) while the slot we're emitting may
                # be `:modulo`. Different storage names can have
                # different eligibility decisions (e.g. one of them
                # has a block-bearing caller, disqualifying that
                # name only). Look up under the storage name.
                lookup_name = storage_name || method.name
                sig = @natural_arity_names && @natural_arity_names[lookup_name]
                return build_natural_arity_override(method, sig) if sig
                family = @multi_arity_table && @multi_arity_table[lookup_name]
                return build_multi_arity_override(method, family, storage_name: lookup_name) if family
                kw_sig = @kw_unset_table && @kw_unset_table[lookup_name]
                return build_kw_unset_override(method, kw_sig) if kw_sig
                # Pre-walk for captured locals (inner-block-referenced
                # locals get heap-cell storage; see CppBox::Cpp.captured_locals).
                # Includes block-locals hoisted by collect_local_writes
                # so they share the same captured? check as the bare
                # method-level decl unpack_params emits for them.
                captured = method.body ? MethodEmitter.collect_method_captured(method) : Set.new
                needs_frame = false
                body = @cpp.with_captured_locals(captured) do
                  capture do
                    needs_frame = @cpp.with_frame_id_tracking do
                      locals = MethodEmitter.unpack_params(self, method)
                      ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
                    end
                  end
                end
                # Wrap in try/catch ReturnException so `return v` inside
                # a Proc body escapes via throw and lands at the
                # ENCLOSING METHOD'S frame (this one). The frame ID
                # is unique per invocation (next_frame_id() is atomic-
                # incremented). Inner method catches re-raise on
                # frame-ID mismatch — a `return` inside a block created
                # by method A and called by method B targets A's
                # frame, so B's catch must propagate it through.
                # Without frame-targeting, B catches it and search-
                # like patterns (list.fetch(k) {return nil}) silently
                # break — fetch's catch swallows the throw meant for
                # search.
                # Stage 3 visibility prologue: for P4 (mixed-vis) names
                # with non-public bodies, check `g_caller_self` at entry
                # so the universal-slot dispatch can decide private/
                # protected at runtime per the receiver's class.
                vis_prologue = MethodEmitter.visibility_prologue_text(
                  @visibility_survey, storage_name || method.name, method.visibility, body: method.body
                )
                {
                  params: [],
                  body: MethodEmitter.body_with_frame_text(body, needs_frame, vis_prologue: vis_prologue),
                }
              end
            end
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && @strict_emit
            log_skip("method", method, e)
            # When the override sits on top of a hand-coded ancestor
            # implementation (Object#=== etc.), returning nil here lets
            # the parent's hand-coded virtual stay in effect via C++
            # inheritance — a working fallback that's better than
            # abort-stubbing the slot.
            return nil if fall_through_on_error
            # Otherwise emit an abort-stub body so calls into this
            # skipped method at runtime fail loudly with a "compiler
            # limitation" message, rather than the previous silent-skip
            # (return nil from missing override) which produced
            # confusing downstream NoMethodErrors / wrong values. Caller
            # may rescue NoMethodError and silently swallow our gap;
            # abort can't.
            loc = method&.source_location || "(unknown)"
            mname = method.respond_to?(:name) ? method.name : "?"
            msg = "[frozone-box-first] unimplemented method :#{mname} (def @ #{loc}): #{e.message}"
            # If the slot is natural-arity-eligible, the abort-stub
            # signature must match the natural-arity decl emitted by
            # write_override_decl — otherwise decl/def disagree and
            # the link step fails. Use the storage name for the
            # eligibility lookup (same as the eligibility check at
            # build_override entry).
            lookup_name = storage_name || (method.respond_to?(:name) ? method.name : nil)
            sig = lookup_name && @natural_arity_names && @natural_arity_names[lookup_name]
            family = lookup_name && @multi_arity_table && @multi_arity_table[lookup_name]
            kw_sig = lookup_name && @kw_unset_table && @kw_unset_table[lookup_name]
            abort_body = %|std::fprintf(stderr, "%s\\n", #{@cpp.cpp_string_literal(msg)});\nstd::abort();\n|
            if family
              entries = family.arities.to_a.sort.map do |k|
                { params: (0...k).map { |i| "BO* _arg#{i}" }, body: abort_body }
              end
              return { multi_arity: entries }
            end
            if kw_sig
              # kw_unset slot: pos-required + pos-optional + all kw
              # names, all `BO*`. Must match the layout
              # emitted by build_kw_unset_override above and the
              # decl emitted by write_override_decl.
              params = (0...kw_sig.arity_req).map { |i| "BO* _arg#{i}" } +
                       (0...kw_sig.opt).map { |i| "BO* _arg#{kw_sig.arity_req + i}" } +
                       kw_sig.all_kw_names.map { |kn| "BO* _kw_#{kn}" }
              return { params: params, body: abort_body, kw_unset: true }
            end
            if sig
              params = (0...sig.arity_req).map { |i| "BO* _arg#{i}" }
              params += sig.required_kw_names.map { |kn| "BO* _kw_#{kn}" }
              params << "BO* /*block*/" if sig.has_block
            else
              params = []
            end
            {
              params: params,
              body: abort_body,
            }
          end

          # Set @cpp.super_context for the duration of yield. Carries
          # the info needed by Ast::Super lowering: host class, the
          # current method's chain, and the current origin index.
          def with_super_context(ctx)
            return yield if ctx.nil?
            prev = @cpp.super_context
            @cpp.super_context = ctx
            yield
          ensure
            @cpp.super_context = prev if ctx
          end

          # Run `yield` with @cpp.method_scope set to the method's
          # lexical scopes; restore after. Constant resolution inside
          # the body uses Ruby-style outward lookup against this scope.
          def with_method_scope(method)
            prev = @cpp.method_scope
            @cpp.method_scope = method.scopes || []
            yield
          ensure
            @cpp.method_scope = prev
          end

          # Emit a one-line debug log when FROZONE_BOX_DEBUG=1 — surfaces
          # which method/ctor/class was dropped and why. Off by default
          # (would otherwise spam ~hundreds of lines per program).
          # FROZONE_BOX_HARD_FAIL=1 re-raises the EmissionError instead
          # — useful when chasing self-compile bugs that hide behind
          # silently-skipped methods.
          def log_skip(kind, method, err)
            return unless ENV['FROZONE_BOX_DEBUG'] == '1'
            loc = method.respond_to?(:source_location) ? method.source_location : nil
            $stderr.puts "[box-first] skip #{kind} #{method&.name} @ #{loc}: #{err.message}"
          end

          # Diagnostic pass — count how many classes define each method
          # name. Single-def names are candidates for direct dispatch
          # (no virtual table slot needed); multi-def names need
          # genuine virtual dispatch. Run with FROZONE_BOX_ANALYSIS=1.
          # Disqualify names whose runtime/universe.rb definition is
          # a raw C++ declaration listed in hand_coded_method_names —
          # m_send, m_method_missing, mm_kind_of_q etc. Those bodies
          # live as full `BO* X(Array*, Hash*, BO*)`
          # methods, so natural-arity emission on the same slot would
          # mismatch decl vs def.
          #
          # Note: `overrides` is intentionally NOT disqualified. Override
          # specs are shaped `params: ["BO* x", ...]` with a
          # body that uses the named params directly; write_override_def
          # routes them through the natural-arity path when eligibility
          # says so, so they coexist cleanly. This covers arithmetic
          # ops (op_plus, op_minus, op_lt, …) and most Integer / Float /
          # String operator overrides.
          # The cpp_name → Ruby_name mapping is many-to-one for
          # operators: `:**` and `:pow` both map to `op_pow`,
          # `:<<` and (occasionally) other names to `op_lshift`, etc.
          # When `Math.pow(x, y)` (arity 2) collides with `Integer#**`
          # (arity 1) on the same `op_pow` slot, the override specs
          # carry different param counts even though the survey only
          # knows one arity for the Ruby name. Emitting natural-arity
          # would produce a decl that disagrees with one of the
          # override bodies. Prune those names from @natural_arity_names
          # by walking overrides and looking for arity disagreements.
          # Returns the count pruned (for the activation summary).
          def prune_override_arity_collisions
            pruned = 0
            @natural_arity_names.delete_if do |ruby_name, sig|
              cpp = Cpp.method_name(ruby_name)
              n = sig.arity_req
              # Module/Class singletons (Math.pow, Math.hypot, …) live
              # in `eigenclass_overrides` on the RubyClass itself, not
              # via a separate eigenclass object. Check both maps.
              collide = Runtime::ALL_CLASSES.any? do |k|
                instance = (k.overrides || {})[cpp]
                singleton = (k.respond_to?(:eigenclass_overrides) ? k.eigenclass_overrides : nil) || {}
                singleton_spec = singleton[cpp]
                (instance && (instance[:params] || []).length != n) ||
                  (singleton_spec && (singleton_spec[:params] || []).length != n)
              end
              pruned += 1 if collide
              collide
            end
            pruned
          end

          # Drop multi-arity names where any class has a hand-coded
          # method or overlay override at the cpp slot. A hand-coded
          # body has a single fixed signature that can't simultaneously
          # cover every per-arity overload in the family — the
          # cross-class wrong-args stub work needed to fill the gaps is
          # post-beachhead. Conservative prune today; relax once full
          # per-arity emission lands.
          # Drop a multi-arity name only when the override's signature
          # can't be fitted into the per-arity slot family. Hand-coded
          # inline methods (in `hand_coded_method_names`) live as
          # universal-sig bodies in BasicObject's struct and can't be
          # reshaped — always drop. Spec-based overrides whose
          # params.length matches one of the family arities CAN be
          # emitted as the per-arity slot for that arity, with wrong-
          # args stubs at the other arities (write_override_def
          # handles this when spec is single-form on a multi-arity name).
          # Spec is a per-arity-wrappable body iff its body doesn't
          # reference the universal-sig `args` / `kwargs` / `block`
          # parameters directly. Some hand-coded specs have params=[]
          # but use `args->data` in the body (e.g. Random#rand) — those
          # are universal-sig in disguise and can't be re-emitted at a
          # per-arity slot signature.
          def spec_body_universal_sig_in_disguise?(spec)
            body = spec[:body].to_s
            body =~ /\bargs\b/ || body =~ /\bkwargs\b/ || body =~ /\bblock\b/
          end

          def prune_multi_arity_override_collisions
            pruned = 0
            debug = ENV['FROZONE_NATURAL_ARGS_DEBUG'] == 'prune'
            @multi_arity_table.delete_if do |ruby_name, family|
              cpp = Cpp.method_name(ruby_name)
              incompatible_class = nil
              incompatible_kind = nil
              Runtime::ALL_CLASSES.each do |k|
                if (k.hand_coded_method_names || []).include?(cpp)
                  incompatible_class = k.name
                  incompatible_kind = "hand_coded_inline"
                  break
                end
                override = (k.overrides || {})[cpp]
                singleton = (k.respond_to?(:eigenclass_overrides) ? k.eigenclass_overrides : nil) || {}
                sing = singleton[cpp]
                if override
                  if !family.arities.include?((override[:params] || []).length)
                    incompatible_class = k.name
                    incompatible_kind = "override(params=#{(override[:params] || []).length})"
                    break
                  end
                  if spec_body_universal_sig_in_disguise?(override)
                    incompatible_class = k.name
                    incompatible_kind = "override(body uses args/kwargs/block)"
                    break
                  end
                end
                if sing
                  if !family.arities.include?((sing[:params] || []).length)
                    incompatible_class = k.name
                    incompatible_kind = "singleton(params=#{(sing[:params] || []).length})"
                    break
                  end
                  if spec_body_universal_sig_in_disguise?(sing)
                    incompatible_class = k.name
                    incompatible_kind = "singleton(body uses args/kwargs/block)"
                    break
                  end
                end
              end
              if incompatible_class
                $stderr.puts "[multi-arity-prune] :#{ruby_name} arities=#{family.arities.to_a.sort} dropped by #{incompatible_class} (#{incompatible_kind})" if debug
                pruned += 1
                true
              else
                false
              end
            end
            pruned
          end

          # Same conservative prune as multi-arity: drop kw_unset names
          # where any class has a hand-coded or overlay override at the
          # cpp slot. The kw_unset slot signature has a fixed param
          # count that wouldn't match a hand-coded body, and per-class
          # overlap with hand-coded paths is too risky for a first pass.
          # kw_unset has a single fixed slot signature (total_slots
          # params). Override is wrappable iff its params.length equals
          # total_slots — then it IS the slot body.
          def prune_kw_unset_override_collisions
            pruned = 0
            debug = ENV['FROZONE_NATURAL_ARGS_DEBUG'] == 'prune'
            @kw_unset_table.delete_if do |ruby_name, sig|
              cpp = Cpp.method_name(ruby_name)
              incompatible_class = nil
              incompatible_kind = nil
              Runtime::ALL_CLASSES.each do |k|
                if (k.hand_coded_method_names || []).include?(cpp)
                  incompatible_class = k.name
                  incompatible_kind = "hand_coded_inline"
                  break
                end
                override = (k.overrides || {})[cpp]
                singleton = (k.respond_to?(:eigenclass_overrides) ? k.eigenclass_overrides : nil) || {}
                sing = singleton[cpp]
                if override && (override[:params] || []).length != sig.total_slots
                  incompatible_class = k.name
                  incompatible_kind = "override(params=#{(override[:params] || []).length})"
                  break
                end
                if sing && (sing[:params] || []).length != sig.total_slots
                  incompatible_class = k.name
                  incompatible_kind = "singleton(params=#{(sing[:params] || []).length})"
                  break
                end
              end
              if incompatible_class
                $stderr.puts "[kw-unset-prune] :#{ruby_name} slots=#{sig.total_slots} dropped by #{incompatible_class} (#{incompatible_kind})" if debug
                pruned += 1
                true
              else
                false
              end
            end
            pruned
          end

          def compute_hand_coded_disqualified_names
            Set.new.tap do |set|
              Runtime::ALL_CLASSES.each do |k|
                (k.hand_coded_method_names || []).each do |cpp|
                  next if cpp.start_with?("c_", "sm_")
                  set << cpp_name_to_ruby(cpp).to_sym
                end
              end
            end
          end

          # Walks the post-pruning surface: every reachable method def
          # (filtered by @call_surface) and every reachable Ast::MethodCall
          # inside those bodies (plus the top-level execute block).
          # Returns a populated MethodShapeSurvey::Aggregate. Activated by
          # FROZONE_METHOD_SHAPES=1 (print report) or FROZONE_NATURAL_ARGS=1
          # (consume eligibility for codegen). See method_shape_survey.rb.
          # Names whose body contains an internal block-flow construct
          # (yield or block_given?) in at least one of their reachable
          # defs, without declaring a &blk param. Such methods rely on
          # the implicit caller block: natural-arity codegen has
          # nowhere to receive a block, so emitting them as natural-
          # arity would either silently drop the block or NPE on the
          # yield path. Disqualified from eligibility regardless of
          # def-shape. Populated during build_method_shape_survey.
          attr_reader :internal_block_users

          def build_method_shape_survey
            agg = MethodShapeSurvey::Aggregate.new
            @internal_block_users = Set.new

            visit_methods_on = lambda do |cls, &block|
              next unless cls.is_a?(Vm::ModuleObject)
              (cls.methods_table || {}).each { |n, m| block.call(n, m, cls) if m.is_a?(Vm::Method) }
              if (eig = (cls.eigenclass rescue nil))
                (eig.methods_table || {}).each { |n, m| block.call(n, m, eig) if m.is_a?(Vm::Method) }
              end
            end

            each_reachable_def = lambda do |&block|
              @user_classes.each_value { |cls| visit_methods_on.call(cls, &block) }
              top = @top_level_scope.constants_table || {}
              Runtime::ALL_CLASSES.each { |uk| visit_methods_on.call(top[uk.name.to_sym], &block) }
              # Top-level methods belong to the MainObject scope — no
              # `cls` context. Pass nil; record_def_class skips nil.
              user_methods.each { |n, m| block.call(n, m, nil) if m.is_a?(Vm::Method) }
            end

            # Record def shape under the STORAGE Ruby name (the
            # table key on the class), NOT method.name. Aliases
            # share a Vm::Method body: `alias + chain` registers the
            # same chain method under both `:chain` (its method.name)
            # and `:+`. The C++ VT slot for `:+` on Enumerable has to
            # have a signature that matches chain's shape (variadic),
            # so chain's shape MUST count toward `:+`'s eligibility —
            # otherwise we'd later try to emit Enumerable::op_plus
            # with natural-arity and abort-stub it on the mismatch,
            # silently breaking `enum + other`.
            #
            # Trade-off: a single aliased name with a non-simple
            # shape disqualifies the original name from eligibility
            # (Enumerable's chain-as-+ keeps `:+` from being eligible
            # even though Integer/Float/Array/String all have simple
            # `def +(other)`). Closed-world alias collapsing
            # (project_alias_collapsing.md) is the principled fix —
            # rewrite call sites of aliased names to the canonical,
            # drop the redundant VT slot.
            each_reachable_def.call do |name, method, cls|
              next unless @call_surface.key?(Cpp.method_name(name))
              agg.record_def(name, MethodShapeSurvey::DefShape.for_method(method))
              agg.record_def_class(name, cls) if cls
            end

            walk_calls = lambda do |node, enclosing_name|
              return unless node.is_a?(Ast::Node)
              return if node.is_a?(Ast::MethodDef)
              if node.is_a?(Ast::MethodCall)
                agg.record_call(node.name, MethodShapeSurvey::CallShape.for_call(node))
                # block_given? in a body == implicit reliance on caller
                # block. Same blocker as yield for natural-arity emission.
                @internal_block_users << enclosing_name if enclosing_name && node.name == :block_given?
              elsif node.is_a?(Ast::Yield)
                # Body yields to the caller-supplied block. Cannot
                # natural-arity emit (no block slot).
                @internal_block_users << enclosing_name if enclosing_name
              end
              node.children.each { |c| walk_calls.call(c, enclosing_name) }
            end

            walk_calls.call(@execute_block, nil) if @execute_block
            each_reachable_def.call do |name, method, _cls|
              next unless @call_surface.key?(Cpp.method_name(name))
              method_walkable_roots(method).each { |r| walk_calls.call(r, name) }
            end

            # Block-escape analysis. Per-def → aggregate per-name → fixed
            # point. The result feeds `maybe_stack_alloc_block` at call
            # sites: a name is stack-alloc-safe iff no def of it escapes
            # the block, transitively across &-forwards.
            local_escapes_by_name = Hash.new { |h, k| h[k] = false }
            forwards_by_name = Hash.new { |h, k| h[k] = Set.new }
            each_reachable_def.call do |name, method, _cls|
              next unless @call_surface.key?(Cpp.method_name(name))
              local, fwd = MethodShapeSurvey.analyze_def_block_escape(method)
              local_escapes_by_name[name] ||= local
              forwards_by_name[name].merge(fwd)
            end
            all_names = agg.all_names.to_set | local_escapes_by_name.keys.to_set
            @non_escaping_block_names = MethodShapeSurvey.non_escaping_block_names(
              local_escapes_by_name, forwards_by_name, all_names,
            )

            agg
          end

          def print_method_def_analysis
            defs_by_name = Hash.new { |h, k| h[k] = [] }
            user_classes_with_universe = Runtime::ALL_CLASSES.map(&:name) + @user_classes.keys.map(&:to_s)
            walked = Set.new
            walk = ->(scope, prefix) {
              return if walked.include?(scope.object_id)
              walked << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                fname = prefix ? "#{prefix}::#{name}" : name.to_s
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  (val.methods_table || {}).each_key { |m| defs_by_name[m] << "#{fname}#" }
                  if val.respond_to?(:eigenclass) && val.eigenclass
                    (val.eigenclass.methods_table || {}).each_key { |m| defs_by_name[m] << "#{fname}." }
                  end
                  walk.call(val, fname)
                end
              end
            }
            walk.call(@top_level_scope, nil)
            single = defs_by_name.select { |_, ds| ds.size == 1 }
            multi  = defs_by_name.select { |_, ds| ds.size > 1 }
            total  = defs_by_name.size
            $stderr.puts "[box-first analysis]"
            $stderr.puts "  total method names:  #{total}"
            $stderr.puts "  single-def:          #{single.size} (#{(single.size * 100.0 / total).round(1)}%)"
            $stderr.puts "  multi-def:           #{multi.size} (#{(multi.size * 100.0 / total).round(1)}%)"
            $stderr.puts ""
            $stderr.puts "  multi-def histogram (count of names by # of defining classes):"
            buckets = Hash.new(0)
            multi.each_value { |ds| buckets[ds.size] += 1 }
            buckets.sort.each { |n, count| $stderr.puts "    #{n.to_s.rjust(4)} classes: #{count} method names" }
            $stderr.puts ""
            $stderr.puts "  top multi-def methods:"
            multi.sort_by { |_, ds| -ds.size }.first(15).each do |name, ds|
              $stderr.puts "    #{ds.size.to_s.rjust(4)}  :#{name}"
            end
          end

          def write_header
            # frozone.cpp top: include the PCH cache root so gcc
            # uses frozone_all.hpp.gch.  Plus layouts.hpp explicitly:
            # this TU references Type, Errno_, all-classes via the
            # MainObject body and singleton initializers, so it
            # genuinely needs the full meta-include.
            line %(#include "#{@base_name}_all.hpp")
            line %(#include "#{@base_name}_layouts.hpp")
            # frozone_main_impl catches SystemExitException — just
            # the helpers header; this TU doesn't call any C++
            # `intrinsic_X` directly (those are reached via the per-
            # class method bodies in their own TUs).
            line %(#include "../../../runtime/intrinsics_helpers.hpp")
            blank
          end

          # frozone_layouts.hpp top — the shared header all TUs include.
          # Builds up incrementally through TU split steps:
          #   step 2: just #pragma once + includes + empty namespace
          #   step 3 (current): + forward decls of structs and free fns
          #   step 4: + full struct definitions
          #   step 5: + extern declarations of singletons / globals
          # Open/close split so other writers can target the :layouts
          # stream and have their content appear inside namespace Ruby.
          # frozone_base.hpp — universal scaffolding that every per-class
          # TU needs before any class struct is visible. Stage 1 of the
          # layouts.hpp split (project_layouts_split.md). Carries:
          # forward decls, METHOD_NAMES table, IS_A/CLASS_BY_ID externs,
          # kernel-fn decls, class-var storage.
          def write_base_open
            line "#pragma once"
            # Gen lives at cpp/gen/<backend>/<base>/ — three levels below cpp/,
            # so cross-tree includes into cpp/runtime/ traverse ../../../.
            line %(#include "../../../runtime/box_first.hpp")
            blank
            line "namespace Ruby {"
            blank
            # Forward declarations for free functions whose definitions
            # live in dedicated TUs (universe, static, …). Lets the
            # other TUs' callers (frozone.cpp's frozone_main_impl etc.)
            # find them at link time.
            line "void __init_static_state__();  // defined in frozone_static.cpp"
            line "int frozone_main_impl(int argc, char** argv);  // defined in frozone.cpp"
            blank
          end

          def write_base_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          # frozone_layouts.hpp — meta-header (Stage 2 of the layouts.hpp
          # split). Opens with #include "frozone_base.hpp", then includes
          # every per-class class/<Name>.hpp in topo order (each per-class
          # hpp opens its own `namespace Ruby { ... }` block), then ends
          # with `#include "frozone_post.hpp"` (Stage 3 Path 2 — moved
          # post-class content to its own header). Used by frozone.cpp /
          # frozone_universe.cpp / frozone_static.cpp which genuinely
          # need the whole world. Per-class TUs use frozone_post.hpp
          # directly + their precise per-class refs.
          def write_layouts_open
            line "#pragma once"
            line %(#include "#{@base_name}_base.hpp")
            blank
          end

          def write_layouts_close
            blank
            line %(#include "#{@base_name}_post.hpp")
            blank
          end

          # Universal value-type classes whose hpps frozone_post.hpp
          # transitively pulls in. Required because the post-class
          # content (int literals, EMPTY_ARGS/KWARGS, intrinsic
          # templates that cast to these) needs the full struct
          # definitions visible. ~15 hpps × ~100 lines each ≪ the
          # 660-class layouts.hpp meta-header — that's the per-TU win.
          # Order matters: hpps with inline methods that cast to
          # other universal types must come AFTER those types' hpps.
          # Array's ctor casts to Integer*, Integer's hpp doesn't
          # cast to Array — so Integer first. When in doubt: simple
          # leaf types first, then complex types.
          POST_HPP_VALUE_TYPES = %w[
            BasicObject Object Module Class
            Symbol
            Integer Float
            String
            NilClass TrueClass FalseClass
            Array Hash
            Proc Proc0 Proc1 Proc2
            Range Regexp MatchData
            Exception NoMethodError RuntimeError
            Random Time ThrownTag
          ].freeze

          # frozone_post.hpp — receives the post-class content moved
          # out of frozone_layouts.hpp under Stage 3 Path 2. Per-class
          # TUs include this in place of layouts.hpp.
          def write_post_open
            line "#pragma once"
            line %(#include "#{@base_name}_base.hpp")
            POST_HPP_VALUE_TYPES.each do |t|
              line %(#include "class/#{t}.hpp")
              line %(#include "class/#{t}#{Reachability::EIG_SUFFIX}.hpp")
            end
            blank
            line "namespace Ruby {"
            blank
            # Positional-arity check helpers. Hot path is a single
            # integer compare with a predicted-not-taken branch; cold
            # path is the (non-inline) raise_arity_* declared in
            # frozone_base.hpp and defined in frozone_universe.cpp.
            # Every emitted user method body calls one of these at
            # entry (after the kwargs fold) — see MethodEmitter#emit_arity_check.
            line "inline void check_arity_fixed(std::size_t given, std::size_t expected) {"
            line "  if (given != expected) [[unlikely]] raise_arity_fixed(given, expected);"
            line "}"
            line "inline void check_arity_range(std::size_t given, std::size_t lo, std::size_t hi) {"
            line "  if (given < lo || given > hi) [[unlikely]] raise_arity_range(given, lo, hi);"
            line "}"
            line "inline void check_arity_min(std::size_t given, std::size_t lo) {"
            line "  if (given < lo) [[unlikely]] raise_arity_min(given, lo);"
            line "}"
            blank
          end

          def write_post_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          # frozone_all.hpp — PCH cache root. Per-class TUs start
          # with `#include "frozone_all.hpp"` so gcc loads
          # frozone_all.hpp.gch (which captures the entire AST of
          # base + post + layouts) in one cached step. Decouples the
          # PCH input from what the build actually depends on: when
          # we eventually drop layouts.hpp (Stage 4 of the layouts
          # split), we just remove that line here — per-class .cpp
          # first-include doesn't change.
          def write_all_hpp_open
            line "#pragma once"
            line %(#include "#{@base_name}_base.hpp")
            line %(#include "#{@base_name}_post.hpp")
            line %(#include "#{@base_name}_int_literals.hpp")
            # Stage 4: layouts.hpp dropped from the PCH cache root.
            # Per-class .cpps now rely on host_class_refs (lexical-
            # scope-aware via Reachability.resolve_const_to_flat)
            # plus the const-stub auto-collection. Auxiliary TUs
            # (frozone.cpp/universe/static) include layouts.hpp
            # explicitly.
            blank
          end

          def write_all_hpp_close
            blank
          end

          # frozone_int_literals.hpp — extern decls for the
          # interned Integer literals + raw int64_t tables. Pure
          # extern decls + arrays; needs only base.hpp's forward
          # decl of Integer.
          def write_int_literals_hpp_open
            line "#pragma once"
            line %(#include "#{@base_name}_base.hpp")
            blank
            line "namespace Ruby {"
            blank
          end
          def write_int_literals_hpp_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          # frozone_int_literals.cpp — single TU that holds all the
          # `Integer _f_i_N(NLL);` storage. Needs Integer struct
          # complete (for the constructor), so includes class/Integer.hpp.
          def write_int_literals_cpp_open
            line %(#include "#{@base_name}_base.hpp")
            line %(#include "class/Integer.hpp")
            line %(#include "#{@base_name}_int_literals.hpp")
            blank
            line "namespace Ruby {"
            blank
          end
          def write_int_literals_cpp_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          # frozone_universe.cpp — definitions of all kernel_fns and
          # intrinsic helpers. layouts.hpp has their (non-inline)
          # forward decls; universe.cpp has the unique definitions.
          # Lets per-class TUs and the static-state TU call them
          # without ODR violations or inline-ism.
          def write_universe_open
            line %(#include "#{@base_name}_all.hpp")
            line %(#include "#{@base_name}_layouts.hpp")
            # frozone_universe.cpp holds kernel-fn bodies, the IS_A
            # LUT, and the method VT — no `intrinsic_X` calls land
            # here, so no per-category intrinsics header is needed.
            blank
            line "namespace Ruby {"
            blank
          end

          def write_universe_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          # frozone_static.cpp — `__init_static_state__()` definition.
          # The huge AOT-time-captured constant initializers (lexer
          # tables, class instance ivars) live here. Extracting it from
          # frozone.cpp shrinks the main TU and (with PCH) lets it
          # compile in parallel with class TUs.
          def write_static_open
            line %(#include "#{@base_name}_all.hpp")
            line %(#include "#{@base_name}_layouts.hpp")
            # frozone_static.cpp = __init_static_state__: Onigmo
            # init, class_id wiring, singleton ctors. No
            # `intrinsic_X` calls in the gen here either.
            blank
            line "namespace Ruby {"
            blank
          end

          def write_static_close
            blank
            line "}  // namespace Ruby"
            blank
          end

          def write_namespace_open
            line "namespace Ruby {"
            blank
          end

          def write_namespace_close
            line "}  // namespace Ruby"
            blank
          end

          def write_main_object
            with_strict_emit do
              line "struct MainObject : Object {"
              indented do
                line %(const char* ruby_class_name() const override { return "MainObject"; })
                write_user_methods
                blank
                line "void __top_level__() {"
                indented { write_top_level_body }
                line "}"
              end
              line "};"
              blank
            end
          end

          def write_user_methods
            user_methods.each do |name, method|
              blank
              MethodEmitter.write_user_method(self, name, method)
            end
          end

          # Walk the top-level body for every name that gets a
          # LocalVariableWrite or MultipleAssignment-target AT
          # __top_level__'s OWN scope. Stops at Block/Lambda boundaries
          # — names declared inside an inner block are block-local
          # (not hoisted to top-level), so they don't belong here.
          def collect_top_level_own_locals(body)
            names = Set.new
            walk = ->(node) {
              return unless node.is_a?(Ast::Node)
              return if node.is_a?(Ast::Block) || node.is_a?(Ast::Lambda)
              names << node.name.to_s if node.is_a?(Ast::LocalVariableWrite)
              if node.is_a?(Ast::MultipleAssignment) && node.respond_to?(:targets)
                node.targets.each do |t|
                  next unless t.is_a?(Array)
                  names << t[1].to_s if t[1].is_a?(Symbol) && %i[local local_splat].include?(t[0])
                end
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            }
            walk.call(body) if body
            names
          end

          def write_top_level_body
            return unless @execute_block
            body = @execute_block.respond_to?(:body) ? @execute_block.body : @execute_block
            # Pre-walk for captured locals at top-level scope. Inner
            # procs (like the .on(...) blocks of an OptionParser.new
            # do |opts| ... end) capture top-level locals like
            # `l_options`; those need heap-cell storage so the procs
            # see the updated value when invoked, not a stale one.
            top_own = collect_top_level_own_locals(body)
            top_captured = LambdaEmitter.collect_captured_locals(body, top_own)
            @cpp.captured_locals = top_captured
            # Wrap in try/catch ReturnException so a `return` thrown
            # from a Proc body called from top-level code lands here
            # (matches the wrap in MethodEmitter#write_user_method).
            # Without it, a stray throw escapes main() as
            # "terminate called after throwing 'ReturnException'".
            # Top-level has its own __frame_id__; mismatched throws
            # are stray returns from procs whose enclosing method
            # already returned (would be LocalJumpError in MRI).
            line "std::uint64_t __frame_id__ = next_frame_id();"
            line "try {"
            indented do
              if trace?
                stmts = body.is_a?(Ast::Sequence) ? body.nodes : [body]
                line %|std::fprintf(stderr, "[trace] __top_level__ start (%d stmts)\\n", #{stmts.size});|
                # Don't wrap each stmt in try{}: top-level locals
                # (l_options etc.) need to cross stmt boundaries.
                # Throws bypass the "done" line; only the outer catch
                # logs them.
                locals = Set.new
                stmts.each_with_index do |n, i|
                  loc = n.respond_to?(:source_location) && n.source_location ? n.source_location.compact.join(":") : "(unknown)"
                  label = "[trace] top-level stmt #{i}/#{stmts.size - 1} @ #{loc}"
                  line %|std::fprintf(stderr, "%s — entering\\n", #{cpp.cpp_string_literal(label)});|
                  ExprEmitter.write_body(self, Ast::Sequence.new([n]), locals: locals)
                  line %|std::fprintf(stderr, "%s — done\\n", #{cpp.cpp_string_literal(label)});|
                end
                line %|std::fprintf(stderr, "[trace] __top_level__ end\\n");|
              else
                ExprEmitter.write_body(self, body, locals: Set.new)
              end
            end
            if trace?
              line "} catch (ReturnException& e_) {"
              indented { line %|std::fprintf(stderr, "[trace] __top_level__ caught ReturnException (target=%llu, frame=%llu)\\n", (unsigned long long)e_.target_frame, (unsigned long long)__frame_id__);| }
              line "} catch (BO* e_) {"
              indented do
                line %|std::fprintf(stderr, "[trace] __top_level__ caught Ruby exception: %s\\n", e_->ruby_class_name());|
                line "throw;  // re-raise so main()'s handler still sees it"
              end
              line "}"
            else
              line "} catch (ReturnException& e_) { /* top-level return — stray (target=#{0} mismatch ignored) */ }"
            end
          end

          # Trace points are emitted in the gen when FROZONE_BOX_TRACE
          # is set at AOT time. They're stderr fprintfs at the
          # boundaries we use for "where did the silent exit happen?"
          # debugging — currently __init_static_state__ start/end and
          # each top-level statement's begin/end with source location.
          # Method-entry tracing is a follow-up (much higher volume).
          def trace? = ENV['FROZONE_BOX_TRACE'] == '1'

          # Body of the program entry. Lives inside `namespace Ruby` in
          # the default stream so it has direct access to the runtime
          # types. The actual `int main()` is a tiny trampoline emitted
          # in :main stream (write_main_trampoline) that calls this.
          def write_main_impl
            line "int frozone_main_impl(int argc, char** argv) {"
            indented do
              line "FROZONE_GC_INIT();"
              line "__init_static_state__();"
              # Populate ARGV from C++ argc/argv. Pre-AOT k_ARGV() is a
              # static empty Array snapshot; without this the runtime
              # binary ignores its command-line args entirely. argv[0]
              # is the program name (matches Ruby's $PROGRAM_NAME, not
              # ARGV), so start from argv[1].
              line "if (auto* arr = Ruby::BO::try_cast<Ruby::Array>(Ruby::k_ARGV())) {"
              indented do
                line "for (int i = 1; i < argc; i++) arr->data.push_back(new Ruby::String(argv[i]));"
              end
              line "}"
              line "Ruby::MainObject mo;"
              line "try {"
              indented do
                line "mo.__top_level__();"
              end
              # Kernel#exit / exit! throw SystemExitException; terminate
              # with its status (ensures already ran during unwinding).
              line "} catch (Ruby::SystemExitException& se) {"
              indented do
                line "std::fflush(stdout);"
                line "return static_cast<int>(se.status);"
              end
              # Defensive safety net for a ThrownTag escaping all
              # `intrinsic_kernel_catch` frames. Shouldn't happen now
              # that kernel_catch converts uncaught throws to
              # UncaughtThrowError on the outermost mismatch — but if
              # one slips through (raw `throw` from a path that never
              # entered kernel_catch), terminate would be the next
              # stop. Report and exit non-zero instead.
              line "} catch (Ruby::ThrownTag* t) {"
              indented do
                line %|std::fprintf(stderr, "uncaught throw\\n");|
                line "(void)t;"
                line "return 1;"
              end
              line "} catch (Ruby::BO* e) {"
              indented do
                # Print the exception class + iv_message (if any) to
                # stderr. iv_message is the Exception's `@message`
                # ivar set by Exception#initialize. Mirrors Ruby's
                # `(uncaught exception)` shape.
                line "std::fprintf(stderr, \"%s\", e->ruby_class_name());"
                line "if (e->mm_is_a_q_direct(&Ruby::Exception_CLASS)) {"
                indented do
                  line "auto* exc = static_cast<Ruby::Exception*>(e);"
                  line "if (auto* msg = Ruby::BO::try_cast<Ruby::String>(exc->iv_message)) {"
                  indented do
                    line "std::fputs(\": \", stderr);"
                    line "std::fwrite(msg->bytes.data(), 1, msg->bytes.size(), stderr);"
                  end
                  line "}"
                end
                line "}"
                line "std::fputc('\\n', stderr);"
                line "return 1;"
              end
              line "}"
              line "return 0;"
            end
            line "}"
          end

          # Tiny `int main()` wrapper that lives in its own translation
          # unit (frozone_main.cpp). All it does is forward-declare and
          # call frozone_main_impl in namespace Ruby.
          def write_main_trampoline
            line "// Generated trampoline. Forwards to frozone_main_impl"
            line "// defined in frozone.cpp's namespace Ruby."
            blank
            line "namespace Ruby { int frozone_main_impl(int argc, char** argv); }"
            blank
            line "int main(int argc, char** argv) {"
            indented { line "return Ruby::frozone_main_impl(argc, argv);" }
            line "}"
          end

          # Materialise every reachable Vm value that exists at AOT
          # time but isn't a literal in the program:
          #   - ClassObject ivars (set via `self.X = ...` at class-body
          #     level — the ragel-generated lexer tables are the
          #     canonical case)
          #   - Nested user-constants' ivars (e.g. `Encoding::BINARY`
          #     has @name = "ASCII-8BIT" etc.)
          # Failures (unsupported value type, unresolved class) skip
          # that one ivar with a comment.
          # Snapshot wire lines grouped by owning source file (memoized —
          # wire_node has side effects, e.g. int-literal registration, so
          # it must run exactly once).
          def snapshot_wire_groups = @snapshot_wire_groups ||= @snapshot.wire_groups

          # Per-owner snapshot wiring TUs. Each owning file's local objects
          # (~94% of the graph) are wired in their own
          # frozone_static_<owner>.cpp via __init_static_<owner>__(), so
          # editing one class recompiles only its small wiring TU (and the
          # 132 TUs compile in parallel). Precise includes — just the
          # receiver structs the lines cast to — keep each TU off the full
          # layouts.hpp parse. SHARED objects stay in frozone_static.cpp.
          def write_snapshot_owner_tus
            snapshot_wire_groups.each do |owner, g|
              next if owner == Snapshot::SHARED || g[:lines].empty?
              with_stream(:"static_#{owner}") do
                line %(#include "#{@base_name}_all.hpp")
                g[:structs].to_a.sort.each { |c| line %(#include "class/#{c}.hpp") }
                blank
                line "namespace Ruby {"
                blank
                line "void __init_static_#{owner}__() {"
                indented { g[:lines].each { |l| line l } }
                line "}"
                blank
                line "}  // namespace Ruby"
                blank
              end
            end
          end

          def write_static_state_init
            # Forward-declare the per-owner wiring entry points (defined in
            # their own frozone_static_<owner>.cpp TUs) so the dispatcher
            # below can call them.
            snapshot_wire_groups.each do |owner, g|
              next if owner == Snapshot::SHARED || g[:lines].empty?
              line "void __init_static_#{owner}__();"
            end
            line "void __init_static_state__() {"
            indented do
              line %|std::fprintf(stderr, "[trace] __init_static_state__ start\\n");| if trace?
              # Onigmo regex engine — must run before any Regexp
              # construction. Cheap (registers UTF-8 encoding tables).
              line "init_onigmo();"
              # Eigenclass singleton class-id population — drives
              # is_a?'s LUT lookup. Also goes via static state init
              # (singletons are constructed before main; we're just
              # filling the field after that).
              (@class_ids_for_init || {}).each do |flat_name, cid|
                # All emitted classes have a paired _CLASS singleton
                # (eigenclass_for is called for every entry). Skip
                # plain instance classes — their ids end up on the
                # eigenclass via instance_class_id_.
                next if flat_name.end_with?(Reachability::EIG_SUFFIX)
                line "#{flat_name}_CLASS.instance_class_id_ = #{cid};"
              end
              @user_classes.each do |flat, cls|
                (cls.instance_variables_hash || {}).each do |name, val|
                  emit_static_iv_assign("#{flat}_CLASS", flat, name, val)
                end
              end
              # Snapshot object graph, distributed by owning source file.
              # SHARED objects (reached from >=2 files) are wired here in
              # frozone_static.cpp (it parses full layouts.hpp anyway); each
              # owning file's local objects are wired by its own
              # __init_static_<owner>__() TU, dispatched below. Accessors
              # self-allocate lazily on first call, so cross-TU order and
              # cycles resolve regardless of dispatch order.
              shared = snapshot_wire_groups[Snapshot::SHARED]
              (shared ? shared[:lines] : []).each { |l| line l }
              snapshot_wire_groups.each do |owner, g|
                next if owner == Snapshot::SHARED || g[:lines].empty?
                line "__init_static_#{owner}__();"
              end
              # Class variables: snapshot each class's @class_variables
              # captured during load phase. Only emit assignments for
              # cvars that have been referenced during emission (i.e.
              # appear in @cpp.class_vars), since unused cvars don't
              # have storage to set.
              @cpp.class_vars.each do |host, names|
                cls = @user_classes[host.to_sym]
                next unless cls.respond_to?(:class_variables)
                cvars = cls.class_variables || {}
                names.each do |n|
                  key = :"@@#{n}"
                  next unless cvars.key?(key)
                  expr = @cpp.emit_vm_value(cvars[key]) rescue nil
                  next unless expr
                  line "cv_#{host}__#{n} = #{expr};"
                end
              end
              line %|std::fprintf(stderr, "[trace] __init_static_state__ end\\n");| if trace?
            end
            line "}"
            blank
          end

          def emit_static_iv_assign(target_expr, label, ivar_name, val)
            iv = ivar_name.to_s.delete_prefix('@')
            expr = @cpp.emit_vm_value(val)
            line "#{target_expr}.iv_#{iv} = #{expr};"
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && @strict_emit
            line "// skipped #{label}.iv_#{iv}: #{e.message.gsub('*/', '* /')}"
            $stderr.puts "[box-first] skip static-init #{label}.iv_#{iv}: #{e.message}" if ENV['FROZONE_BOX_DEBUG'] == '1'
          end

          # Top-level user methods (not on a class).
          def user_methods
            (@top_level_scope.methods_table || {}).select do |_, m|
              m.is_a?(Vm::Method) && user_source?(m.source_location)
            end
          end

          CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

          def user_source?(loc)
            return false if loc.nil?
            file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
            return false if @stub_file && file == @stub_file
            CORE_PATH_MARKERS.none? { |m| file.include?(m) }
          end
        end
      end
    end
  end
end
