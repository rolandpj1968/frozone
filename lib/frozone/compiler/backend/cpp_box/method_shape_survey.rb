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
            # that shape is simple-positional (no opt, rest, kw,
            # kwrest, block_param) — and no caller passes a block to
            # the name. simple_kw_only? is a forthcoming extension
            # (DefShape tracks required_kw_names ready for that step);
            # the gate is here, not in the data layer.
            def eligible_def_shape(name)
              shapes = @defs[name]
              return nil unless shapes.size == 1
              shape = shapes.keys.first
              return nil unless shape.simple?
              return nil if @calls[name].any? { |c, _| c.blk_pass || c.do_block }
              shape
            end

            def compatible_calls(name)
              shape = eligible_def_shape(name)
              return 0 unless shape
              @calls[name].sum { |c, n| (c.simple? && c.arity_pos == shape.arity_req) ? n : 0 }
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

          def report(agg, io: $stderr)
            names = agg.all_names
            eligible = names.select { |n| agg.eligible?(n) }
            non_eligible = names - eligible
            single_defn = names.select { |n| agg.def_total(n) == 1 }
            single_defn_calls = single_defn.sum { |n| agg.call_total(n) }
            io.puts '[method-shape survey]'
            io.puts "  total method names:  #{names.size}"
            io.puts "  eligible:            #{eligible.size}"
            io.puts "  non-eligible:        #{non_eligible.size}"
            io.puts "  single-defn names:   #{single_defn.size} (#{single_defn_calls} call sites)"
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
