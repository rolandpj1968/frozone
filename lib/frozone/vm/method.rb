module Frozone
  module Vm
    class Method
      # TODO - default params, keyword params, block param
      def initialize(scopes, name, params, locals, ast)
        # TODO - array of class/modules
        raise "scopes must be an array of ClassObjects/ModuleObjects" unless scopes.class.equal?(Array)
        raise "name must be a Symbol" unless name.class.equal?(Symbol)
        # TODO - array of symbols
        raise "params must be an array of Symbols" unless params.class.equal?(Array)
        # TODO - array of symbols
        raise "locals must be an array of Symbols" unless locals.class.equal?(Array)

        @scopes = Method.unique_scopes(scopes)
        @name = name
        @params = params
        @locals = locals
        @ast = ast
      end

      def scopes = @scopes

      def params = @params

      def locals = @locals

      def ast = @ast

      def to_s = "method(#{scopes.map(&:to_s)}, :#{@name}, #{@params} -> #{@ast})"

      def alias_as(name)
        raise "name must be a Symbol" unless name.class.equal?(Symbol)
        # TODO - default params, keyword params, block param - same same
        Method.new(scopes, name, params, locals, ast)
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
