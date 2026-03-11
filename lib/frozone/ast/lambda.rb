require_relative 'node'
require_relative '../vm/block_object'
require_relative '../vm/proc_object'

module Frozone
  module Ast
    class Lambda < Node
      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, locals, body)
        @required_params    = check_array_type("required_params", required_params, Symbol)
        @optional_params    = optional_params
        @rest_param         = rest_param
        @post_params        = check_array_type("post_params", post_params, Symbol)
        @required_kw_params = check_array_type("required_kw_params", required_kw_params, Symbol)
        @optional_kw_params = optional_kw_params
        @kw_rest_param      = kw_rest_param
        @block_param        = block_param
        @locals             = check_array_type("locals", locals, Symbol)
        @body               = check_type("body", body, Node)
      end

      def evaluate(context)
        # Lambdas do NOT auto-splat (auto_splat: false), and have strict arg checking (is_lambda: true)
        block = Vm::BlockObject.new(
          @required_params, @optional_params, @rest_param, @post_params,
          @required_kw_params, @optional_kw_params, @kw_rest_param,
          @block_param, false, @locals, @body, context.frame,
          is_lambda: true
        )
        Vm::ProcObject.new(block, lambda: true)
      end
    end
  end
end
