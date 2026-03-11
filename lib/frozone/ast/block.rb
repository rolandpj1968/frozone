require_relative 'node'
require_relative '../vm/block_object'

module Frozone
  module Ast
    class Block < Node
      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, auto_splat, locals, body, is_lambda: false)
        @required_params    = required_params  # Array of Symbol or {destructure: [names...]} Hash
        @optional_params    = optional_params  # [[name, node], ...]
        @rest_param         = rest_param       # Symbol or nil
        @post_params        = check_array_type("post_params", post_params, Symbol)
        @required_kw_params = check_array_type("required_kw_params", required_kw_params, Symbol)
        @optional_kw_params = optional_kw_params  # [[name, node], ...]
        @kw_rest_param      = kw_rest_param   # Symbol or nil
        @block_param        = block_param     # Symbol or nil
        @auto_splat         = auto_splat      # Boolean
        @is_lambda          = is_lambda       # Boolean: true for lambdas (strict arg checking)
        @locals             = check_array_type("locals", locals, Symbol)
        @body               = check_type("body", body, Node)
      end

      def evaluate(context)
        Vm::BlockObject.new(
          @required_params, @optional_params, @rest_param, @post_params,
          @required_kw_params, @optional_kw_params, @kw_rest_param,
          @block_param, @auto_splat, @locals, @body, context.frame,
          is_lambda: @is_lambda
        )
      end
    end
  end
end
