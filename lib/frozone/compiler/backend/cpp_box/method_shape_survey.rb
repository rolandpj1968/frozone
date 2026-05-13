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
                  kwrest:              !method.kw_rest_param.nil? && method.kw_rest_param != :__no_kwargs__,
                  block_param:         !method.block_param.nil?,
                )
              end

              def intern(arity_req:, opt:, rest:, kw:, opt_kw:, required_kw_names:, kwrest:, block_param:)
                key = [arity_req, opt, rest, kw, opt_kw, required_kw_names, kwrest, block_param]
                @intern[key] ||= new(*key).freeze
              end
            end

            attr_reader :arity_req, :opt, :rest, :kw, :opt_kw, :required_kw_names, :kwrest, :block_param

            def initialize(arity_req, opt, rest, kw, opt_kw, required_kw_names, kwrest, block_param)
              @arity_req = arity_req
              @opt = opt
              @rest = rest
              @kw = kw
              @opt_kw = opt_kw
              @required_kw_names = required_kw_names
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
          NaturalAritySig = Struct.new(:arity_req, :required_kw_names) do
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

          # Per-name histograms over interned DefShape / CallShape keys.
          # Identity-based hash → tally++ is just `bucket[shape] += 1`.
          class Aggregate
            attr_reader :defs, :calls

            def initialize
              @defs  = Hash.new { |h, k| h[k] = Hash.new(0) }
              @calls = Hash.new { |h, k| h[k] = Hash.new(0) }
            end

            def record_def(name, shape)  = @defs[name][shape] += 1
            def record_call(name, shape) = @calls[name][shape] += 1
            def def_total(name)          = @defs[name].each_value.sum
            def call_total(name)         = @calls[name].each_value.sum
            def eligible?(name)          = !eligible_def_shape(name).nil?
            def all_names                = (@defs.keys | @calls.keys).sort

            # Returns the DefShape for an eligible name, else nil.
            # Eligible iff the def-histogram has exactly one bin AND
            # that shape is either pure simple-positional or required-
            # kw-only (no opt, rest, kwrest, optional_kw, block_param).
            # Block-bearing call sites disqualify the name regardless
            # of def-shape — the natural-arity signature has no Block
            # slot.
            def eligible_def_shape(name)
              shapes = @defs[name]
              return nil unless shapes.size == 1
              shape = shapes.keys.first
              return nil unless shape.simple? || shape.simple_kw_only?
              return nil if @calls[name].any? { |c, _| c.blk_pass || c.do_block }
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
          def eligibility_table(agg, exclude: Set.new)
            agg.all_names.each_with_object({}) do |name, h|
              next if exclude.include?(name)
              shape = agg.eligible_def_shape(name)
              h[name] = NaturalAritySig.new(shape.arity_req, shape.required_kw_names.dup) if shape
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
            io.puts '[method-shape survey]'
            io.puts "  total method names:  #{names.size}"
            io.puts "  eligible (v1):       #{eligible.size} names, #{v1_calls} compatible calls"
            io.puts "  non-eligible (v1):   #{non_eligible.size}"
            io.puts "  per-arity (v2):      #{per_arity_names.size} names, #{per_arity_slot_pairs} (name, arity) slots, #{per_arity_calls} compatible calls"
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
