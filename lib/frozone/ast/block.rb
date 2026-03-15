require_relative 'node'
require_relative '../vm/block_object'

module Frozone
  module Ast
    class Block < Node
      attr_reader :required_params, :optional_params, :rest_param, :post_params
      attr_reader :required_kw_params, :optional_kw_params, :kw_rest_param, :block_param
      attr_reader :auto_splat, :locals, :body

      def initialize(required_params, optional_params, rest_param, post_params,
                     required_kw_params, optional_kw_params, kw_rest_param,
                     block_param, auto_splat, locals, body, is_lambda: false, it_param: false,
                     source_location: nil)
        @required_params    = required_params  # Array of Symbol or {destructure: [names...]} Hash
        @optional_params    = optional_params  # [[name, node], ...]
        @rest_param         = rest_param       # Symbol or nil
        @post_params        = post_params
        @required_kw_params = required_kw_params
        @optional_kw_params = optional_kw_params  # [[name, node], ...]
        @kw_rest_param      = kw_rest_param   # Symbol or nil
        @block_param        = block_param     # Symbol or nil
        @auto_splat         = auto_splat      # Boolean
        @is_lambda          = is_lambda       # Boolean: true for lambdas (strict arg checking)
        @it_param           = it_param        # Boolean: true for `it` implicit parameter
        @locals             = locals
        @body               = body
        @source_location    = source_location # [file, line] or nil
      end

      def evaluate(context)
        Vm::BlockObject.new(
          @required_params, @optional_params, @rest_param, @post_params,
          @required_kw_params, @optional_kw_params, @kw_rest_param,
          @block_param, @auto_splat, @locals, @body, context.frame,
          is_lambda: @is_lambda, it_param: @it_param, source_location: @source_location
        )
      end
    end
  end
end
