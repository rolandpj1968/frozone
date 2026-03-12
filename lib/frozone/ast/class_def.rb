require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ClassDef < Node
      def initialize(name, locals, superclass_node, body, namespace_node: nil)
        @name = name

        @locals = locals

        @superclass_node = superclass_node
        @namespace_node  = namespace_node
        @body = body
      end

      def to_s
        "class(#{@name}, locals: #{@locals} body: #{@body})"
      end

      def evaluate(context)
        if @namespace_node
          # Namespaced class: class A::B — define B inside A
          # The namespace A is NOT pushed onto the lexical scope stack; only B is.
          container = @namespace_node.evaluate(context)
          raise Vm::FrozoneException.make(:TypeError, "#{@namespace_node} is not a class/module") unless container.is_a?(Vm::ModuleObject)
          namespace = container
          class_constant = container.get_constant(@name)
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{superclass.class_object&.name} given)") unless superclass.is_a?(Vm::ClassObject)
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            container.set_constant(@name, class_constant)
          elsif @superclass_node
            superclass = @superclass_node.evaluate(context)
            raise Vm::FrozoneException.make(:TypeError, "superclass mismatch for class #{@name}") unless class_constant.superclass.equal?(superclass)
          end
        else
          # Namespace is the innermost enclosing class/module, except at top level where
          # scopes.last is OBJECT_CLASS acting as a container, not a real nesting namespace.
          namespace = context.scopes.last.equal?(Vm::Core::OBJECT_CLASS) ? nil : context.scopes.last

          # 1. find or create the class defn and constant
          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          class_constant = context.scopes.last.get_constant(@name)
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{superclass.class_object&.name} given)") unless superclass.is_a?(Vm::ClassObject)
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            context.scopes.last.set_constant(@name, class_constant)
          elsif @superclass_node
            superclass = @superclass_node.evaluate(context)
            raise Vm::FrozoneException.make(:TypeError, "superclass mismatch for class #{@name}") unless class_constant.superclass.equal?(superclass)
          end
        end

        context.scopes << class_constant
        prev_visibility = class_constant.current_visibility
        class_constant.current_visibility = :public
        new_frame = Vm::Frame.new(class_constant, @locals, context.scopes)
        context.push_frame(new_frame)

        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
          context.scopes.pop
          class_constant.current_visibility = prev_visibility
        end
      end
    end
  end
end
