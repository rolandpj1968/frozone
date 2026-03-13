require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ModuleDef < Node
      def initialize(name, locals, body, namespace_node: nil)
        @name = name

        @locals = locals

        @namespace_node = namespace_node
        @body = body
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
          if container.is_a?(Vm::ModuleObject) && container.constant_private?(@name)
            container_name = container.respond_to?(:name) ? container.name : nil
            label = container_name ? "#{container_name}::#{@name}" : @name.to_s
            raise Vm::FrozoneException.make(:NameError, "private constant #{label} referenced")
          end
          module_constant = container.get_constant(@name)
          unless module_constant.nil? || (module_constant.is_a?(Vm::ModuleObject) && !module_constant.is_a?(Vm::ClassObject))
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a module (#{module_constant.is_a?(Vm::ObjectObject) ? module_constant.class_object&.name : module_constant.class} given)")
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            container.set_constant(@name, module_constant)
          end
        else
          # Use the LEXICAL scope (frame's definition-site scopes) for constant lookup/assignment.
          lex_scope = context.frame.scopes.last
          namespace = lex_scope.equal?(Vm::Core::OBJECT_CLASS) ? nil : lex_scope

          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          module_constant = lex_scope.get_constant(@name)
          unless module_constant.nil? || (module_constant.is_a?(Vm::ModuleObject) && !module_constant.is_a?(Vm::ClassObject))
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a module (#{module_constant.is_a?(Vm::ObjectObject) ? module_constant.class_object&.name : module_constant.class} given)")
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            lex_scope.set_constant(@name, module_constant)
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
