require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ModuleDef < Node
      def initialize(name, locals, body, namespace_node: nil)
        @name = check_type("name", name, Symbol)

        @locals = check_array_type("locals", locals, Symbol)

        @namespace_node = check_nil_or_type("namespace_node", namespace_node, Node)
        @body = check_type("body", body, Node)
      end

      def to_s
        "module(#{@name}, locals: #{@locals} body: #{@body})"
      end

      def evaluate(context)
        if @namespace_node
          # Namespaced module: module A::B — define B inside A
          # The namespace A is NOT pushed onto the lexical scope stack; only B is.
          container = @namespace_node.evaluate(context)
          namespace = container.is_a?(Vm::ModuleObject) ? container : nil
          module_constant = container.get_constant(@name)
          unless module_constant.nil? || module_constant.is_a?(Vm::ModuleObject)
            raise "previous defn of #{@name} was not a module"
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            container.set_constant(@name, module_constant)
          end
        else
          namespace = context.scopes.last.equal?(Vm::Core::OBJECT_CLASS) ? nil : context.scopes.last

          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          module_constant = context.scopes.last.get_constant(@name)
          unless module_constant.nil? || module_constant.is_a?(Vm::ModuleObject)
            raise "previous defn of #{@name} was not a module"
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            context.scopes.last.set_constant(@name, module_constant)
          end
        end

        context.scopes << module_constant
        prev_visibility = module_constant.current_visibility
        module_constant.current_visibility = :public
        new_frame = Vm::Frame.new(module_constant, @locals, context.scopes)
        context.push_frame(new_frame)

        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
          context.scopes.pop
          module_constant.current_visibility = prev_visibility
        end
      end
    end
  end
end
