require_relative '../utils'
require_relative '../ast/node'
require_relative 'frame'

module Frozone
  module Vm
    class Method
      include Utils

      # TODO - default params, keyword params, block param
      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, locals, body)
        @scopes = self.class.unique_scopes(check_array_type("scopes", scopes, ModuleObject))
        @name = check_type("name", name, Symbol)
        @required_params = check_array_type("required_params", required_params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)

        @body = check_type("body", body, Ast::Node)
      end

      # TODO - default params, keyword params, block params
      def invoke(context, receiver, params)
        new_frame = Frame.new(receiver, @locals, @scopes)

        # TODO - this is a runtime error, not an intrinsic error
        raise "wrong number of parameters (given #{params.length} expecting #{@required_params.length})" if params.length != @required_params.length

        @required_params.length.times do |i|
          new_frame.set_local(@required_params[i], params[i])
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
