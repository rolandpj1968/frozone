# Box-first C++ backend — orchestrator.
#
# Parallel to the mainline `Frozone::Compiler::CppEmitter`. Where mainline
# specialises eagerly and falls back to box on TI failure, this emitter
# inverts the polarity: every value is `Ruby::X*` deriving from
# `Ruby::BasicObject`, dispatched via C++ virtual methods. TI-driven
# unboxing is the optimisation pass — added later, on top of an
# always-correct baseline.
#
# Selected via `FROZONE_BOX_FIRST=1` (see ast/frozone_compile.rb).
#
# See memory/project_radical_box_first.md for the pinned plan.
#
# Vocab note: methods that mutate the buffer are `write_*`. Pure
# functions producing cpp strings live on `Cpp` (held as `emit.cpp`).

require_relative 'cpp'
require_relative 'class_emitter'
require_relative 'method_emitter'
require_relative 'expr_emitter'
require_relative '../../module_flattening'
require_relative '../../reachability'

module Frozone
  module Compiler
    module Backend
      module CppBox
        class Emitter
          attr_reader :cpp, :top_level_scope, :user_classes, :user_constants
          # When true, emission errors inside method bodies re-raise
          # under FROZONE_BOX_HARD_FAIL=1 instead of graceful-skipping.
          # Toggled true while emitting user-class bodies + the
          # execute_block (program path); left false while overlaying
          # universe-class methods (a method like `Object#instance_exec`
          # is reachable-by-definition but typically never called, and
          # we don't want to abort the build for it).
          attr_accessor :strict_emit

          def initialize
            @out = +""
            @indent = 0
            @strict_emit = false
          end

          def write(*strs) = strs.each { |s| @out << s }
          def line(str) = @out << ("  " * @indent) << str << "\n"
          def blank = @out << "\n"

          def indented
            @indent += 1
            yield
            @indent -= 1
          end

          # Run `yield` with output captured to a string buffer (indent
          # reset). Used for rendering method bodies into RubyClass.overrides
          # body strings — writers commit via line/indented as usual,
          # but the result accumulates into a returned string instead of
          # the main output. ensure-restore so a yield that raises
          # (e.g. graceful-degradation EmissionError) doesn't leak the
          # inner buffer into subsequent writes.
          def capture
            saved_out, saved_indent = @out, @indent
            @out, @indent = +"", 0
            yield
            @out
          ensure
            @out, @indent = saved_out, saved_indent
          end

          def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
            @execute_block = execute_block
            @top_level_scope = top_level_scope
            @globals = globals
            @stub_file = stub_file
            @user_constants = collect_user_constants
            @user_classes = collect_all_classes
            @cpp = Cpp.new(user_classes: @user_classes, user_constants: @user_constants)
            @cpp.emit = self
            @call_surface = collect_call_surface
            @const_surface = collect_dynamic_constant_surface
            print_method_def_analysis if ENV['FROZONE_BOX_ANALYSIS'] == '1'
            all_classes = overlay_universe_methods(Runtime::ALL_CLASSES) + build_user_class_defs
            all_eigenclasses = all_classes.map { |k| Runtime.eigenclass_for(k) }.compact
            decorate_eigenclasses_with_const_overrides(all_classes, all_eigenclasses)
            classes = all_classes + all_eigenclasses
            @class_ids_for_init = classes.each_with_index.to_h { |k, i| [k.name, i] }
            kernel_fns = Runtime::ALL_KERNEL_FNS + build_user_constant_accessors
            write_header
            write_namespace_open
            ClassEmitter.write_runtime(self, classes: classes, call_surface: @call_surface, const_surface: @const_surface, kernel_fns: kernel_fns) do
              write_static_state_init
              write_main_object
            end
            write_namespace_close
            write_main
            @out
          end

          private

          # Walk top_level_scope.constants_table for every Vm::ClassObject.
          # Skip Universe-seeded names (BasicObject, Object, Integer, Array,
          # etc.) — they have hand-coded backing already.
          UNIVERSE_NAMES = Set.new(Runtime::ALL_CLASSES.map(&:name)).freeze

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
              next klass unless cls.is_a?(Vm::ClassObject)
              hand_coded = ancestor_hand_coded_names(klass, by_name)
              # Ivars referenced by overlaid methods need fields on the
              # struct or `this->iv_X` won't compile. Collect them the
              # same way build_user_class_def does for user classes,
              # filtering out anything already in `members:` (some
              # entries — MatchData — declare iv_X by hand for non-nil
              # initial values).
              existing_ivar_names = (klass.members || []).filter_map { |line|
                line[/\biv_([A-Za-z_][A-Za-z_0-9]*)\b/, 1]
              }.to_set
              extra_ivars = collect_ivars(cls)
                .reject { |iv| existing_ivar_names.include?(iv) }
                .map { |iv| "BasicObject* iv_#{iv} = nil_instance();" }
              klass.dup.tap do |k|
                k.overrides = overlay_overrides_chained(klass.name, klass.overrides || {}, class_method_chains(cls), hand_coded)
                # Eigenclass methods don't take super (no MRO walk for
                # def-self-X chains in box-first today), so the flat
                # path is enough.
                k.eigenclass_overrides = overlay_overrides(klass.eigenclass_overrides || {}, eigenclass_methods(cls), hand_coded)
                k.members = (k.members || []) + extra_ivars unless extra_ivars.empty?
              end
            end
          end

          # Union of hand_coded_method_names across the runtime ancestor
          # chain. The hand-coded methods on BasicObject (m_is_a_q with
          # the IS_A LUT, m_freeze, m_class, …) are the load-bearing
          # implementations — overlaying their core/4.0/ Ruby twins via
          # virtual dispatch would shadow them and recurse.
          def ancestor_hand_coded_names(klass, by_name)
            names = Set.new
            current = klass
            while current
              (current.hand_coded_method_names || []).each { |n| names << n }
              current = current.parent && by_name[current.parent]
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
              next unless @call_surface&.key?(cpp_name)
              spec = build_override(m)
              merged[cpp_name] = spec if spec
            end
            merged
          end

          # Chain-aware overlay: head of each chain → m_X (gated by
          # hand_coded + existing overrides), tail → sm_X__from_<Origin>
          # always emitted (no hand-coded equivalents of shadowed slots).
          def overlay_overrides_chained(host_name, existing_overrides, chains, hand_coded)
            merged = existing_overrides.dup
            chains.each do |mname, entries|
              # Method-level reachability gate — same as build_chained_overrides.
              next unless @call_surface&.key?(Cpp.method_name(mname))
              entries.each_with_index do |(origin, method), idx|
                cpp_name = idx.zero? ? Cpp.method_name(mname) : Cpp.shadowed_method_name(mname, origin)
                next if merged.key?(cpp_name)
                next if idx.zero? && hand_coded.include?(cpp_name)
                ctx = { host_name: host_name, method_name: mname, origin_index: idx, chain: entries }
                spec = build_override(method, super_ctx: ctx)
                merged[cpp_name] = spec if spec
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
                flat = prefix ? :"#{prefix}_#{name}" : name
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
            Vm::ArrayObject, Vm::HashObject
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
            seen = Set.new
            walk = ->(scope, prefix) {
              return if seen.include?(scope.object_id)
              seen << scope.object_id
              (scope.constants_table || {}).each do |name, val|
                flat = prefix ? :"#{prefix}_#{name}" : name
                if val.is_a?(Vm::ClassObject) || val.is_a?(Vm::ModuleObject)
                  walk.call(val, flat)
                elsif val.is_a?(Vm::ObjectObject)
                  consts[flat] = val
                end
              end
            }
            walk.call(@top_level_scope, nil)
            consts
          end

          def build_user_constant_accessors
            @user_constants.map do |name, val|
              if primitive_vm_value?(val)
                # Primitive — emit_vm_value gives the literal expr.
                # Cached in a static for identity stability + skip
                # re-evaluation cost on subsequent calls.
                expr = (@cpp.emit_vm_value(val) rescue "nil_instance() /* failed: #{$!&.message} */")
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BasicObject* k_#{name}()",
                  body: "static BasicObject* val = #{expr}; return val;",
                )
              else
                # Snapshot ObjectObject — default-construct (no
                # m_initialize call), let __init_static_state__
                # populate ivars from the Vm instance.
                klass_name = val.class_object.full_name.to_s.gsub("::", "_")
                Runtime::KernelFn.new(
                  name: "k_#{name}",
                  signature: "BasicObject* k_#{name}()",
                  body: "static BasicObject* val = new #{klass_name}(); return val;",
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
          # m_respond_to_q / m_method_missing / m_const_missing).
          def collect_call_surface
            calls = {}
            seen_ruby_names = Set.new
            reached_bodies = Set.new
            worklist = []
            symbol_literals = Set.new

            schedule_body = lambda do |body|
              next if body.nil?
              next unless reached_bodies.add?(body.object_id)
              worklist << body
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
            add_method = lambda do |ruby_name|
              next unless seen_ruby_names.add?(ruby_name)
              cpp_name = Cpp.method_name(ruby_name)
              calls[cpp_name] ||= ruby_name.to_s
              method_bodies_named(ruby_name).each(&schedule_body)
            end

            walk = lambda do |node|
              next unless node.is_a?(Ast::Node)
              if node.is_a?(Ast::MethodCall) || node.is_a?(Ast::AttributeWrite)
                add_method.call(node.name)
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
              end
              node.children.each { |c| walk.call(c) } if node.respond_to?(:children)
            end

            # Seed pre-walk:
            #   - Hand-coded universe overrides + hand_coded_method_names
            #     live directly on the class struct and need slots on
            #     BasicObject's universal surface for `override` to
            #     type-check on derived classes.
            #   - Auto-included fallbacks referenced from generated code
            #     (m_new, m_initialize, m_class, m_respond_to_q,
            #     m_method_missing, m_const_missing).
            # All seeded BEFORE the walk loop so transitive references
            # from their implementing bodies get picked up.
            seed_names = Set.new
            # m_hash_value is a C++-internal hook (returns std::size_t,
            # used by unordered_map<BasicObject*, ...>) — not a Ruby
            # method despite the m_ prefix. Excluded from METHOD_VT
            # since its signature doesn't match the universal protocol.
            non_ruby_hand_coded = %w[m_hash_value].to_set
            Runtime::ALL_CLASSES.each do |k|
              (k.overrides || {}).each_key { |cpp| seed_names << cpp unless cpp.start_with?("c_", "sm_") || non_ruby_hand_coded.include?(cpp) }
              (k.hand_coded_method_names || []).each { |cpp| seed_names << cpp unless cpp.start_with?("c_", "sm_") || non_ruby_hand_coded.include?(cpp) }
            end
            seed_names.merge(%w[m_new m_initialize m_class m_respond_to_q m_method_missing m_const_missing])
            seed_names.each { |cpp| add_method.call(cpp_name_to_ruby(cpp).to_sym) }

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

            schedule_body.call(@execute_block)
            user_methods.each_value do |m|
              next unless m.is_a?(Vm::Method)
              method_walkable_roots(m).each { |r| schedule_body.call(r) }
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
              walk.call(worklist.shift) until worklist.empty?
              if send_names.any? { |n| calls.key?(n) }
                added = false
                symbol_literals.each do |sym|
                  next if seen_ruby_names.include?(sym)
                  bodies = method_bodies_named(sym)
                  next if bodies.empty?
                  add_method.call(sym)
                  added = true
                end
                break unless added
              end
            end

            if ENV['FROZONE_BOX_DEBUG'] == '1'
              $stderr.puts "[box-first] method-level surface: #{calls.size} methods"
            end
            calls
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
          # ClassEmitter.cpp_name_to_ruby — couldn't reuse directly
          # because of module nesting.
          def cpp_name_to_ruby(cpp)
            inv = Cpp::OP_NAMES.invert
            return inv[cpp].to_s if inv.key?(cpp)
            s = cpp.to_s.sub(/^m_/, '').sub(/_q$/, '?').sub(/_set$/, '=')
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
              host_name = eigen.name.sub(/_eigenclass\z/, '')
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
              next unless cls.is_a?(Vm::ClassObject)
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
              ivars: ivars.map { |iv| "BasicObject* iv_#{iv} = nil_instance();" },
              members: [%(const char* ruby_class_name() const override { return "#{name}"; })],
              # No special ctor — `initialize` becomes a regular
              # `m_initialize` override; eigenclass auto-emits `m_new`
              # that does `new X(); m_initialize(...); return obj;`.
              overrides: build_chained_overrides(name.to_s, class_method_chains(cls)),
              eigenclass_overrides: eigenclass_methods(cls).each_with_object({}) { |(mname, m), h|
                cpp_name = Cpp.method_name(mname)
                next unless @call_surface.key?(cpp_name)
                spec = build_override(m)
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
          def build_chained_overrides(host_name, chains)
            result = {}
            # Hand-coded ancestor methods (m_class, m_send, m_is_a_q, …)
            # have load-bearing C++ implementations we must NOT shadow
            # with the Ruby-level def from Kernel/Object. E.g.
            # Kernel#class lowers to `this->m_class()`; if a user class
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
              next unless @call_surface&.key?(cpp_name)
              if hand_coded.include?(cpp_name)
                head_origin, _ = entries.first
                next if head_origin != :self
              end
              entries.each_with_index do |(origin, method), idx|
                # Class-origin entries don't get sm_X slots on the host
                # — super lowers them to qualified `this->Parent::m_X`,
                # using C++ inheritance directly. Module-origin entries
                # (and the head, idx=0) DO get slots emitted here.
                next if idx.positive? && origin.is_a?(Vm::ClassObject)
                cpp_name = idx.zero? ? Cpp.method_name(mname) : Cpp.shadowed_method_name(mname, origin)
                ctx = { host_name: host_name, method_name: mname, origin_index: idx, chain: entries }
                spec =
                  begin
                    build_override(method, super_ctx: ctx)
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
                params: ["BasicObject* v"],
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
              ivars: members.map { |m| "BasicObject* iv_#{m} = nil_instance();" },
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
          def eigenclass_methods(cls)
            eigen = cls.eigenclass rescue nil
            return {} unless eigen
            top_level_methods = (@top_level_scope.methods_table || {})
            (eigen.methods_table || {}).select do |name, m|
              next false unless m.is_a?(Vm::Method)
              top_level_methods[name] != m
            end
          end

          # Collect ivars from the cls's parent chain (cls's
          # superclass, its superclass, ...). Used to filter out
          # already-declared ivars when emitting a derived struct,
          # avoiding C++ field shadowing.
          def collect_parent_ivars(cls)
            seen = Set.new
            sc = cls.respond_to?(:superclass) ? cls.superclass : nil
            while sc && sc.respond_to?(:full_name) && sc.full_name &&
                  sc.full_name != :Object
              flat = sc.full_name.to_s.gsub("::", "_").to_sym
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
            sc.full_name.to_s.gsub("::", "_")
          end

          # Build a ctor spec for a user class. Required params land as
          # `BasicObject* x`; optional params get C++ default-arg syntax
          # (`BasicObject* x = <default_expr>`). Rest/post/kw params are
          # not yet supported in ctors — raise EmissionError so the
          # whole class falls through to a default ctor (callsites that
          # try to instantiate it with args will then fail to compile,
          # which is the right loud signal).
          # Build an override spec for a user method using unpack_params
          # (so rest/block handling matches MethodEmitter). Empty params
          # field means class_emitter doesn't double-emit unpack lines.
          # EmissionError → nil so caller can drop the entry; the slot
          # falls through to BasicObject's method_missing stub at runtime.
          def build_override(method, super_ctx: nil)
            with_method_scope(method) do
              with_super_context(super_ctx) do
                body = capture do
                  locals = MethodEmitter.unpack_params(self, method)
                  ExprEmitter.write_body(self, method.body, locals: locals, last_is_return: true) if method.body
                end
                {
                  params: [],
                  body: body + "return nil_instance();\n",
                }
              end
            end
          rescue Cpp::EmissionError => e
            raise if ENV['FROZONE_BOX_HARD_FAIL'] == '1' && @strict_emit
            log_skip("method", method, e)
            # Emit an abort-stub body so calls into this skipped method
            # at runtime fail loudly with a "compiler limitation"
            # message, rather than the previous silent-skip (return nil
            # from missing override) which produced confusing downstream
            # NoMethodErrors / wrong values. Caller may rescue
            # NoMethodError and silently swallow our gap; abort can't.
            loc = method&.source_location || "(unknown)"
            mname = method.respond_to?(:name) ? method.name : "?"
            msg = "[frozone-box-first] unimplemented method :#{mname} (def @ #{loc}): #{e.message}"
            {
              params: [],
              body: %|std::fprintf(stderr, "%s\\n", #{@cpp.cpp_string_literal(msg)});\nstd::abort();\n|,
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
            line %(#include "../../runtime/box_first.hpp")
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

          def write_top_level_body
            return unless @execute_block
            body = @execute_block.respond_to?(:body) ? @execute_block.body : @execute_block
            ExprEmitter.write_body(self, body, locals: Set.new)
          end

          def write_main
            line "int main() {"
            indented do
              line "FROZONE_GC_INIT();"
              line "Ruby::__init_static_state__();"
              line "Ruby::MainObject mo;"
              line "try {"
              indented do
                line "mo.__top_level__();"
              end
              line "} catch (Ruby::BasicObject* e) {"
              indented do
                # Print the exception class + iv_message (if any) to
                # stderr. iv_message is the Exception's `@message`
                # ivar set by Exception#initialize. Mirrors Ruby's
                # `(uncaught exception)` shape.
                line "std::fprintf(stderr, \"%s\", e->ruby_class_name());"
                line "if (auto* exc = dynamic_cast<Ruby::Exception*>(e)) {"
                indented do
                  line "if (auto* msg = dynamic_cast<Ruby::String*>(exc->iv_message)) {"
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

          # Materialise every reachable Vm value that exists at AOT
          # time but isn't a literal in the program:
          #   - ClassObject ivars (set via `self.X = ...` at class-body
          #     level — the ragel-generated lexer tables are the
          #     canonical case)
          #   - Nested user-constants' ivars (e.g. `Encoding::BINARY`
          #     has @name = "ASCII-8BIT" etc.)
          # Failures (unsupported value type, unresolved class) skip
          # that one ivar with a comment.
          def write_static_state_init
            line "void __init_static_state__() {"
            indented do
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
                next if flat_name.end_with?("_eigenclass")
                line "#{flat_name}_CLASS.instance_class_id_ = #{cid};"
              end
              @user_classes.each do |flat, cls|
                (cls.instance_variables_hash || {}).each do |name, val|
                  emit_static_iv_assign("#{flat}_CLASS", flat, name, val)
                end
              end
              @user_constants.each do |flat, obj|
                next if primitive_vm_value?(obj)  # literals have no ivars
                klass = obj.class_object.full_name.to_s.gsub("::", "_")
                target = "(*static_cast<#{klass}*>(k_#{flat}()))"
                (obj.instance_variables_hash || {}).each do |name, val|
                  emit_static_iv_assign(target, flat, name, val)
                end
              end
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
