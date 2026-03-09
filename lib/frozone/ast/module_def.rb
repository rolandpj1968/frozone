require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ModuleDef < Node
      def initialize(name, locals, body)
        @name = check_type("name", name, Symbol)

        raise "module defn with locals not yet supported" unless locals.empty?
        @locals = check_array_type("locals", locals, Symbol)

        @body = check_type("body", body, Node)
      end

      def to_s
        "module(#{@name}, locals: #{@locals} body: #{@body})"
      end

      def evaluate(context)
        namespace = context.scopes.last.equal?(Vm::Core::OBJECT_CLASS) ? nil : context.scopes.last

        module_constant = Vm::ModuleObject.lookup_constant(@name, context.scopes)
        unless module_constant.nil? || module_constant.is_a?(Vm::ModuleObject)
          raise "previous defn of #{@name} was not a module"
        end
        if module_constant.nil?
          module_constant = Vm::ModuleObject.new(@name, namespace)
          context.scopes.last.set_constant(@name, module_constant)
        end

        context.scopes << module_constant
        module_constant.current_visibility = :public
        new_frame = Vm::Frame.new(module_constant, @locals, context.scopes)
        context.push_frame(new_frame)

        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
          context.scopes.pop
        end
      end
    end
  end
end
