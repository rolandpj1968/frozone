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
                  arity_req:   method.required_params.length + method.post_params.length,
                  opt:         method.optional_params.length,
                  rest:        !method.rest_param.nil?,
                  kw:          !method.required_kw_params.empty? || !method.optional_kw_params.empty?,
                  kwrest:      !method.kw_rest_param.nil? && method.kw_rest_param != :__no_kwargs__,
                  block_param: !method.block_param.nil?,
                )
              end

              def intern(arity_req:, opt:, rest:, kw:, kwrest:, block_param:)
                key = [arity_req, opt, rest, kw, kwrest, block_param]
                @intern[key] ||= new(*key).freeze
              end
            end

            attr_reader :arity_req, :opt, :rest, :kw, :kwrest, :block_param

            def initialize(arity_req, opt, rest, kw, kwrest, block_param)
              @arity_req = arity_req
              @opt = opt
              @rest = rest
              @kw = kw
              @kwrest = kwrest
              @block_param = block_param
            end

            def simple? = opt.zero? && !rest && !kw && !kwrest && !block_param

            def to_s
              parts = ["arity_req=#{@arity_req}"]
              parts << "opt=#{@opt}" if @opt.positive?
              parts << 'rest' if @rest
              parts << 'kw' if @kw
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

            def eligible_def_shape(name)
              shapes = @defs[name]
              return nil unless shapes.size == 1
              shape = shapes.keys.first
              return nil unless shape.simple?
              # Tightened v1 rule: any block-bearing call site (blk_pass
              # or do_block) disqualifies the name. Block support is a
              # v2 enhancement — for now eligible names are entirely
              # block-free at the C++ signature level.
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

          # Returns Hash[Symbol => Int] of eligible names → arity_req.
          # Empty if no names pass eligibility. Consumed by codegen
          # under FROZONE_NATURAL_ARGS=1.
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
              h[name] = shape.arity_req if shape
            end
          end

          def report(agg, io: $stderr)
            names = agg.all_names
            eligible = names.select { |n| agg.eligible?(n) }
            non_eligible = names - eligible
            io.puts '[method-shape survey]'
            io.puts "  total method names:  #{names.size}"
            io.puts "  eligible:            #{eligible.size}"
            io.puts "  non-eligible:        #{non_eligible.size}"
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
