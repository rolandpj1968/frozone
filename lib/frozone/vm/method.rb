require_relative "../utils"

module Frozone
  module Vm
    class Method
      include Utils

      attr_reader :scopes, :name, :required_params, :optional_params, :rest_param, :post_params, :locals, :ast

      # TODO - default params, keyword params, block param
      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, locals, ast)
        @scopes = Method.unique_scopes(check_array_type("scopes", scopes, ModuleObject))
        @name = check_type("name", name, Symbol)
        @required_params = check_array_type("required_params", required_params, Symbol)
        @locals = check_array_type("locals", locals, Symbol)

        @ast = ast
      end

      # TODO
      def to_s = "method(#{scopes.map(&:to_s)}, :#{name}, #{required_params} -> #{ast})"

      def alias_as(name)
        # TODO - default params, keyword params, block param - same same
        Method.new(scopes, name, required_params, optional_params, rest_param, post_params, locals, ast)
      end

      # TODO - thread-safety
      # TODO - surely this does not belong here? There must be other uses of unique scopes?
      UniqueScopes = {}

      def self.unique_scopes(scopes)
        # TODO - thread safety
        value = UniqueScopes[scopes]
        return value unless value.nil?
        frozen_scopes = scopes.dup.freeze
        UniqueScopes[frozen_scopes] = frozen_scopes
      end
    end
  end
end
