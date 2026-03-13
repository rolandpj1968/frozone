require_relative 'node'
require_relative '../vm/block_object'
require_relative '../vm/proc_object'

module Frozone
  module Ast
    class Lambda < Node
      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, locals, body, it_param: false)
        @required_params    = required_params
        @optional_params    = optional_params
        @rest_param         = rest_param
        @post_params        = post_params
        @required_kw_params = required_kw_params
        @optional_kw_params = optional_kw_params
        @kw_rest_param      = kw_rest_param
        @block_param        = block_param
        @it_param           = it_param
        @locals             = locals
        @body               = body
      end

      def evaluate(context)
        # Lambdas do NOT auto-splat (auto_splat: false), and have strict arg checking (is_lambda: true)
        block = Vm::BlockObject.new(
          @required_params, @optional_params, @rest_param, @post_params,
          @required_kw_params, @optional_kw_params, @kw_rest_param,
          @block_param, false, @locals, @body, context.frame,
          is_lambda: true, it_param: @it_param
        )
        Vm::ProcObject.new(block, lambda: true)
      end
    end
  end
end
