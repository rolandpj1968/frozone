require_relative '../utils'
require_relative '../ast/node'
require_relative 'frame'
require_relative 'array_object'

module Frozone
  module Vm
    class Method
      include Utils

      # TODO - default params, keyword params, block param
      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, locals, body)
        @scopes = self.class.unique_scopes(check_array_type("scopes", scopes, ModuleObject))
        @name = check_type("name", name, Symbol)
        @required_params = check_array_type("required_params", required_params, Symbol)
        @optional_params = check_array_of_pairs_of_types("optional_params", optional_params, Symbol, Ast::Node)
        @rest_param = check_nil_or_type("rest_param", rest_param, Symbol)
        @post_params = check_array_type("post_params", post_params, Symbol)
        raise "post_params but no rest_param" if rest_param.nil? && post_params.any?
        @locals = check_array_type("locals", locals, Symbol)

        @body = check_type("body", body, Ast::Node)
      end

      def min_params_allowed = @required_params.length + @post_params.length

      def max_params_allowed
        return nil unless @rest_param.nil?

        min_params_allowed + @optional_params.length
      end

      # TODO - default params, keyword params, block params
      def invoke(context, receiver, params)
        min_params_expected = min_params_allowed
        max_params_expected = max_params_allowed

        if params.length < min_params_expected || (max_params_expected && max_params_expected < params.length)
          # TODO - this is a runtime ArgumentError, not an intrinsic error
          expecting = "#{min_params_expected}"
          if max_params_expected.nil?
            expecting += "+"
          elsif min_params_expected != max_params_expected
            expecting += "..#{max_params_expected}"
          end

          raise "wrong number of arguments (given #{params.length} expecting #{expecting})"
        end

        new_frame = Frame.new(receiver, @locals, @scopes)

        @required_params.length.times do |i|
          new_frame.set_local(@required_params[i], params[i])
        end

        @post_params.length.times do |i|
          new_frame.set_local(@post_params[i], params[i - @post_params.length])
        end

        unless @rest_param.nil?
          new_frame.set_local(@rest_param, ArrayObject.new(params[@required_params.length .. -@post_params.length - 1]))
        end

        context.push_frame(new_frame)
        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
        end
      end

      # TODO
      def to_s = "method(#{@scopes.map(&:to_s)}, :#{@name}, #{@required_params} -> #{@body})"

      def alias_as(name)
        # TODO - default params, keyword params, block param - same same
        Method.new(@scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @locals, @body)
      end

      # TODO - thread-safety
      # TODO - surely this does not belong here? There must be other uses of unique scopes?
      UniqueScopes = {}

      def self.unique_scopes(scopes)
        # TODO - thread safety
        UniqueScopes[scopes] ||= scopes.dup.freeze
      end
    end
  end
end
