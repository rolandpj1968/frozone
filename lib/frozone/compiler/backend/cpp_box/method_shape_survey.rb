require_relative '../../../ast/node'

module Frozone
  module Compiler
    module Backend
      module CppBox
        # Pre-emission analysis: characterise every reachable method
        # def + call site by its parameter / argument shape, then
        # report per-method-name eligibility for natural-arity AOT
        # lowering. Activated by FROZONE_METHOD_SHAPES=1.
        #
        # Eligibility (v1, def-side only): a name is natural-arity
        # eligible iff every reachable def has the "simple positional"
        # shape — no defaults, no rest, no kw, no kwrest, no block
        # param — and all defs share the same required-positional arity.
        #
        # Compatibility is a relation between def-shape and call-shape:
        # a direct call site can statically lower to natural-arity
        # iff the eligible def's arity_req matches the call's arity_pos
        # and the call also has the "simple positional" shape.
        # Incompatible calls stay on the universal calling convention.
        # The dispatch-trampoline is a separate concern, used only by
        # send/method_missing/Method#call traffic — which doesn't show
        # up as a `:name` call site here.
        module MethodShapeSurvey
          class DefShape
            @intern = {}

            class << self
              def for_method(method)
                intern(
                  arity_req:           method.required_params.length + method.post_params.length,
                  opt:                 method.optional_params.length,
                  rest:                !method.rest_param.nil?,
                  kw:                  !method.required_kw_params.empty? || !method.optional_kw_params.empty?,
                  opt_kw:              !method.optional_kw_params.empty?,
                  required_kw_names:   method.required_kw_params.map(&:to_sym).sort,
                  optional_kw_names:   method.optional_kw_params.map { |p, _| p.to_sym }.sort,
                  kwrest:              !method.kw_rest_param.nil? && method.kw_rest_param != :__no_kwargs__,
                  block_param:         !method.block_param.nil?,
                )
              end

              def intern(arity_req:, opt:, rest:, kw:, opt_kw:, required_kw_names:, optional_kw_names:, kwrest:, block_param:)
                key = [arity_req, opt, rest, kw, opt_kw, required_kw_names, optional_kw_names, kwrest, block_param]
                @intern[key] ||= new(*key).freeze
              end
            end

            attr_reader :arity_req, :opt, :rest, :kw, :opt_kw, :required_kw_names, :optional_kw_names, :kwrest, :block_param

            def initialize(arity_req, opt, rest, kw, opt_kw, required_kw_names, optional_kw_names, kwrest, block_param)
              @arity_req = arity_req
              @opt = opt
              @rest = rest
              @kw = kw
              @opt_kw = opt_kw
              @required_kw_names = required_kw_names
              @optional_kw_names = optional_kw_names
              @kwrest = kwrest
              @block_param = block_param
            end

            # No kw at all — natural-arity v1 shape.
            def simple? = opt.zero? && !rest && !kw && !kwrest && !block_param

            # Required-kw-only shape. Same constraints as simple? but
            # required keyword params are allowed. They lower to extra
            # positional slots (kw-name → positional in declaration
            # order). Caller-side rewrites kw at call site → positional.
            def simple_kw_only? = opt.zero? && !rest && !opt_kw && !kwrest && !block_param && kw && !required_kw_names.empty?

            # Per-arity natural eligibility: pure-positional, no rest /
            # kw / kwrest / block_param. Optional positionals (defaults)
            # are fine — they expand into multiple servable arities.
            def natural_eligible_pos? = !rest && !kw && !kwrest && !block_param

            # Block-aware variant of natural_eligible_pos?: same shape
            # constraints, but block_param IS allowed. The Proc* block
            # slot is appended to the C++ signature; bodies can use
            # &blk, yield, and block_given?.
            def natural_eligible_pos_or_block? = !rest && !kw && !kwrest

            # Kw-bearing eligibility (kw_unset path): has at least one
            # kw param (required or optional). Pure positional + kw,
            # no rest / kwrest / block_param. Optional positionals
            # and optional kws use UNSET sentinel at call sites.
            def kw_unset_eligible? = kw && !rest && !kwrest && !block_param

            # The set of positional arities this def can serve. A def
            # with arity_req=A and opt=O serves {A, A+1, …, A+O}. rest
            # adds unbounded arities — treated as "universal slot only"
            # so we don't expand it here.
            def arities_servable
              return [] if rest
              (arity_req..(arity_req + opt)).to_a
            end

            def to_s
              parts = ["arity_req=#{@arity_req}"]
              parts << "opt=#{@opt}" if @opt.positive?
              parts << 'rest' if @rest
              if @kw
                if @required_kw_names.any? && !@opt_kw
                  parts << "kw=[#{@required_kw_names.join(',')}]"
                else
                  parts << 'kw'
                end
              end
              parts << 'kwrest' if @kwrest
              parts << 'block_param' if @block_param
              parts.join(',')
            end
          end

          class CallShape
            @intern = {}

            class << self
              def for_call(call_node)
                pos = 0
                splat = false
                (call_node.arg_nodes || []).each do |a|
                  if a.is_a?(Frozone::Ast::SplatArg)
                    splat = true
                  else
                    pos += 1
                  end
                end
                blk = call_node.block_node
                intern(
                  arity_pos: pos,
                  splat:     splat,
                  kwargs:    !(call_node.kw_arg_nodes || []).empty?,
                  dsplat:    !(call_node.kw_splat_nodes || []).empty?,
                  blk_pass:  blk.is_a?(Frozone::Ast::BlockArg),
                  do_block:  !blk.nil? && !blk.is_a?(Frozone::Ast::BlockArg),
                )
              end

              def intern(arity_pos:, splat:, kwargs:, dsplat:, blk_pass:, do_block:)
                key = [arity_pos, splat, kwargs, dsplat, blk_pass, do_block]
                @intern[key] ||= new(*key).freeze
              end
            end

            attr_reader :arity_pos, :splat, :kwargs, :dsplat, :blk_pass, :do_block

            def initialize(arity_pos, splat, kwargs, dsplat, blk_pass, do_block)
              @arity_pos = arity_pos
              @splat = splat
              @kwargs = kwargs
              @dsplat = dsplat
              @blk_pass = blk_pass
              @do_block = do_block
            end

            def simple? = !splat && !kwargs && !dsplat && !blk_pass && !do_block

            def to_s
              parts = ["arity_pos=#{@arity_pos}"]
              parts << 'splat' if @splat
              parts << 'kwargs' if @kwargs
              parts << 'dsplat' if @dsplat
              parts << 'blk_pass' if @blk_pass
              parts << 'do_block' if @do_block
              parts.join(',')
            end
          end

          # The natural-arity signature for an eligible name. arity_req
          # is the positional count; required_kw_names is the ordered
          # list of required kw param names (empty for simple-positional
          # eligible names). Codegen emits a C++ function with
          # `total_slots` positional parameters — kw names map to extra
          # positional params at the end, in the declaration order
          # recorded here. Call-site lowering rewrites kw arguments
          # into the matching positional slots.
          #
          # has_block: when true, the slot also carries a
          # `Proc* block = nullptr` trailing parameter, and bodies
          # may use yield / block_given? / &blk. Independent of
          # required_kw_names — a name can be has_block AND have
          # required kws.
          NaturalAritySig = Struct.new(:arity_req, :required_kw_names, :has_block) do
            def total_slots = arity_req + required_kw_names.length
          end

          # Per-name family of arities that can be served by natural-
          # arity overloads. `arities` is the set of positional counts
          # K for which at least one def is natural_eligible_pos? and
          # has K in its arities_servable. `needs_universal` is true
          # iff any def for the name uses kw/splat/block_param/kwrest/
          # rest — that def must dispatch through the universal slot.
          # The universal slot coexists with per-arity overloads.
          NaturalArityFamily = Struct.new(:arities, :needs_universal) do
            def empty? = arities.empty?
          end

          # Slot signature for a kw-bearing method (UNSET path). Slot
          # parameter count = arity_req + opt + |all_kw_names|. Order:
          #   - arity_req required positionals (named via the def)
          #   - opt optional positionals (UNSET-able)
          #   - all_kw_names (sorted alphabetical, mix of required +
          #     optional — required slots must be caller-supplied, optional
          #     slots are UNSET-able)
          KwUnsetSig = Struct.new(:arity_req, :opt, :required_kw_names, :optional_kw_names) do
            def all_kw_names = (required_kw_names + optional_kw_names).sort
            def total_slots = arity_req + opt + required_kw_names.length + optional_kw_names.length
            def kw_required?(name) = required_kw_names.include?(name)
          end

          # Per-name histograms over interned DefShape / CallShape keys.
          # Identity-based hash → tally++ is just `bucket[shape] += 1`.
          class Aggregate
            attr_reader :defs, :calls

            def initialize
              @defs  = Hash.new { |h, k| h[k] = Hash.new(0) }
              @calls = Hash.new { |h, k| h[k] = Hash.new(0) }
            end

            def record_def(name, shape)  = @defs[name][shape] += 1
            def record_def_class(name, klass) = (@defining_classes ||= Hash.new { |h, k| h[k] = Set.new })[name] << klass
            def record_call(name, shape) = @calls[name][shape] += 1
            def def_total(name)          = @defs[name].each_value.sum
            def call_total(name)         = @calls[name].each_value.sum
            def eligible?(name)          = !eligible_def_shape(name).nil?
            def all_names                = (@defs.keys | @calls.keys).sort
            def defining_classes(name)   = (@defining_classes ||= {})[name] || Set.new

            # Returns the DefShape for an eligible name, else nil.
            # Eligible iff the def-histogram has exactly one bin AND
            # that shape is pure simple-positional (no opt, rest, kw,
            # kwrest). block_param is admitted — the resulting slot
            # carries a trailing Proc* block param. Block-bearing
            # call sites are also admitted; they pass the block via
            # the same slot. Kw-bearing shapes flow through
            # kw_unset_table instead.
            def eligible_def_shape(name)
              shapes = @defs[name]
              return nil unless shapes.size == 1
              shape = shapes.keys.first
              # simple? requires !block_param; admit block_param as a
              # separate eligibility under natural_eligible_pos_or_block?
              # with opt.zero?. The has_block flag is computed by the
              # caller (eligibility_table) from shape.block_param plus
              # any internal_block_users membership.
              return nil unless shape.opt.zero? && !shape.rest && !shape.kw && !shape.kwrest
              shape
            end

            def compatible_calls(name)
              shape = eligible_def_shape(name)
              return 0 unless shape
              @calls[name].sum { |c, n| (c.simple? && c.arity_pos == shape.arity_req) ? n : 0 }
            end

            # Per-(name, arity) family. Walks every def of `name` and
            # unions the arities each natural-eligible def can serve.
            # Block-bearing call sites disqualify the entire name (the
            # per-arity overload signature has no block slot).
            def arity_family(name)
              shapes = @defs[name]
              return NaturalArityFamily.new(Set.new, false) if shapes.empty?
              return NaturalArityFamily.new(Set.new, true) if @calls[name].any? { |c, _| c.blk_pass || c.do_block }
              arities = Set.new
              needs_universal = false
              shapes.each_key do |shape|
                if shape.natural_eligible_pos?
                  shape.arities_servable.each { |k| arities << k }
                else
                  needs_universal = true
                end
              end
              NaturalArityFamily.new(arities, needs_universal)
            end

            # Per-(name, K) compatible call count: how many call sites
            # for `name` have arity_pos=K and would land on the natural
            # arity-K overload. Used to score the per-arity model.
            def per_arity_compatible_calls(name)
              family = arity_family(name)
              return 0 if family.empty?
              @calls[name].sum do |c, n|
                (c.simple? && family.arities.include?(c.arity_pos)) ? n : 0
              end
            end
          end

          module_function

          # Returns Hash[Symbol => NaturalAritySig] for every eligible
          # name. Empty if no names pass eligibility. Consumed by
          # codegen under FROZONE_NATURAL_ARGS=1.
          #
          # `exclude` is a Set[Symbol] of names to treat as non-
          # eligible regardless of def-shape. Used to disqualify
          # names whose runtime body is hand-written universal-sig
          # (raw `(Array*, Hash*, BasicObject*)` C++); the natural-
          # arity emission path can't co-exist with a universal-sig
          # body on the same VT slot.
          #
          # `internal_block_users` is a Set[Symbol] of names whose
          # bodies use yield / block_given?. Such names get
          # `has_block: true` on their sig so the slot includes the
          # Proc* block trailing param. Names with `block_param: true`
          # in their def also get has_block:true automatically.
          def eligibility_table(agg, exclude: Set.new, internal_block_users: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              shape = agg.eligible_def_shape(name)
              next unless shape
              has_block = shape.block_param || internal_block_users.include?(name)
              h[name] = NaturalAritySig.new(shape.arity_req, shape.required_kw_names.dup, has_block)
            end
          end

          # Returns Hash[Symbol => NaturalArityFamily] for every name
          # with at least one natural-eligible arity. Families with
          # `needs_universal == true` indicate the name also has at
          # least one def that must dispatch via the universal slot.
          # Consumed by the per-arity codegen path (future).
          def family_table(agg, exclude: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              family = agg.arity_family(name)
              h[name] = family unless family.empty?
            end
          end

          # Names with one or more pure-positional def shapes (no kw /
          # splat / block_param / kwrest). The family unions every
          # servable arity from every defining class. Every shape must
          # be natural_eligible_pos? — if any def needs the universal
          # slot (kw / splat / block), drop the name. Block-bearing
          # call sites disqualify the whole family too (no block slot
          # in the per-arity overloads).
          #
          # Kw-bearing eligibility (single shape v1). Names whose one
          # def shape includes at least one kw (required or optional)
          # and is otherwise pure positional + kw. Optional positionals
          # and optional kws use the UnsetSentinel at call sites.
          # Subsumes the old simple_kw_only? subset of eligibility_table.
          def kw_unset_table(agg, exclude: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              shapes = agg.defs[name]
              next if shapes.empty?
              next unless shapes.size == 1
              shape = shapes.keys.first
              next unless shape.kw_unset_eligible?
              next if agg.calls[name].any? { |c, _| c.blk_pass || c.do_block }
              h[name] = KwUnsetSig.new(
                shape.arity_req,
                shape.opt,
                shape.required_kw_names.dup,
                shape.optional_kw_names.dup,
              )
            end
          end

          # What-if: names that WOULD become kw_unset-eligible if we
          # relaxed to multi-shape (any kw-unset-eligible shapes,
          # possibly with different kw sets). Used by the report to
          # size the opportunity before committing to the codegen
          # extension.
          def kw_unset_cross_class_candidates(agg, exclude: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              shapes = agg.defs[name]
              next if shapes.size < 2
              next unless shapes.keys.all?(&:kw_unset_eligible?)
              next if agg.calls[name].any? { |c, _| c.blk_pass || c.do_block }
              h[name] = shapes.keys
            end
          end

          # Mutually exclusive with `eligibility_table` (v1 single-arity
          # pure-positional). Single-shape with opt > 0 (defaults
          # beachhead) and multi-shape cross-class both flow through
          # here — codegen distinguishes them per-class by emitting
          # wrong-args stubs for arities a class's def doesn't serve.
          def multi_arity_table(agg, exclude: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              shapes = agg.defs[name]
              next if shapes.empty?
              # natural_eligible_pos? already requires !kw, so any
              # required_kw / optional_kw shape is filtered here.
              # Mixed-shape names with kw flow through kw_unset_table
              # (when single-shape) or universal (when multi-shape).
              next unless shapes.keys.all?(&:natural_eligible_pos?)
              next if agg.calls[name].any? { |c, _| c.blk_pass || c.do_block }
              arities = shapes.keys.flat_map(&:arities_servable).to_set
              next if arities.empty?
              # v1 (eligibility_table) covers single-arity pure-positional
              # — leave those there to keep the per-arity machinery
              # focused on multi-arity dispatch.
              next if arities.size == 1 && shapes.keys.all? { |s| s.opt.zero? }
              h[name] = NaturalArityFamily.new(arities, false)
            end
          end

          def report(agg, io: $stderr)
            names = agg.all_names
            eligible = names.select { |n| agg.eligible?(n) }
            non_eligible = names - eligible
            single_defn = names.select { |n| agg.def_total(n) == 1 }
            single_defn_calls = single_defn.sum { |n| agg.call_total(n) }
            # What-if: names that WOULD become eligible if we relaxed
            # eligibility to also accept simple_kw_only? shapes
            # (required-kw lowering). One bin, simple-kw-only shape,
            # no block-bearing callers.
            kw_lift = non_eligible.select do |n|
              shapes = agg.defs[n]
              shapes.size == 1 &&
                shapes.keys.first.simple_kw_only? &&
                !agg.calls[n].any? { |c, _| c.blk_pass || c.do_block }
            end
            kw_lift_calls = kw_lift.sum { |n| agg.call_total(n) }
            families = names.each_with_object({}) { |n, h| h[n] = agg.arity_family(n) }
            per_arity_names = families.reject { |_, f| f.empty? }
            per_arity_slot_pairs = per_arity_names.values.sum { |f| f.arities.size }
            per_arity_calls = per_arity_names.keys.sum { |n| agg.per_arity_compatible_calls(n) }
            v1_calls = eligible.sum { |n| agg.compatible_calls(n) }
            defaults_only = multi_arity_table(agg)
            defaults_only_calls = defaults_only.keys.sum { |n| agg.per_arity_compatible_calls(n) }
            kw_unset = kw_unset_table(agg)
            kw_unset_calls = kw_unset.keys.sum { |n| agg.call_total(n) }
            io.puts '[method-shape survey]'
            io.puts "  total method names:  #{names.size}"
            io.puts "  eligible (v1):       #{eligible.size} names, #{v1_calls} compatible calls"
            io.puts "  non-eligible (v1):   #{non_eligible.size}"
            io.puts "  per-arity (v2):      #{per_arity_names.size} names, #{per_arity_slot_pairs} (name, arity) slots, #{per_arity_calls} compatible calls"
            io.puts "  defaults beachhead:  #{defaults_only.size} names, #{defaults_only_calls} compatible calls"
            io.puts "  kw-unset eligible:   #{kw_unset.size} names, #{kw_unset_calls} call sites"
            kw_xclass = kw_unset_cross_class_candidates(agg)
            kw_xclass_calls = kw_xclass.keys.sum { |n| agg.call_total(n) }
            io.puts "  kw-unset xclass cand: #{kw_xclass.size} names, #{kw_xclass_calls} call sites (item 6 unlock)"
            if defaults_only.any?
              top_defaults = defaults_only.sort_by { |n, _| -agg.per_arity_compatible_calls(n) }.first(10)
              top_defaults.each do |n, f|
                shape = agg.defs[n].keys.first
                io.puts "    :#{n.to_s.ljust(38)} arities=#{f.arities.to_a.sort} (#{shape}) — #{agg.per_arity_compatible_calls(n)} calls"
              end
            end
            io.puts "  single-defn names:   #{single_defn.size} (#{single_defn_calls} call sites)"
            io.puts "  +kw-lift candidates: #{kw_lift.size} names, #{kw_lift_calls} call sites"
            io.puts ''
            io.puts '  kw-lift candidates (sorted by call-site count desc):'
            kw_lift.sort_by { |n| -agg.call_total(n) }.first(30).each do |n|
              shape = agg.defs[n].keys.first
              io.puts "    :#{n.to_s.ljust(40)} (#{shape}) — #{agg.call_total(n)} calls"
            end
            io.puts ''
            io.puts '  single-defn shape distribution:'
            shape_buckets = Hash.new { |h, k| h[k] = { count: 0, calls: 0 } }
            single_defn.each do |n|
              shape = agg.defs[n].keys.first
              shape_buckets[shape.to_s][:count] += 1
              shape_buckets[shape.to_s][:calls] += agg.call_total(n)
            end
            shape_buckets.sort_by { |_, v| -v[:calls] }.each do |shape, v|
              io.puts "    #{shape.ljust(50)} #{v[:count]} names, #{v[:calls]} calls"
            end
            io.puts ''
            io.puts '  eligible names (sorted by compatible-call-site count desc):'
            eligible.sort_by { |n| -agg.compatible_calls(n) }.each do |n|
              shape = agg.eligible_def_shape(n)
              compat = agg.compatible_calls(n)
              total = agg.call_total(n)
              defs_n = agg.def_total(n)
              io.puts "    :#{n.to_s.ljust(40)} #{defs_n} defs (#{shape}) — #{compat}/#{total} calls compatible"
            end
            io.puts ''
            io.puts '  non-eligible names (sorted by call-site count desc):'
            non_eligible.sort_by { |n| -agg.call_total(n) }.each do |n|
              defs_n = agg.def_total(n)
              total = agg.call_total(n)
              shapes_summary = agg.defs[n].map { |s, c| "#{c}×{#{s}}" }.join(' + ')
              shapes_summary = '(no defs)' if shapes_summary.empty?
              io.puts "    :#{n.to_s.ljust(40)} #{defs_n} defs: #{shapes_summary} — #{total} calls"
            end
          end
        end
      end
    end
  end
end
