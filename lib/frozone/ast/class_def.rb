require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ClassDef < Node
      def initialize(name, locals, superclass_node, body, namespace_node: nil)
        @name = check_type("name", name, Symbol)

        @locals = check_array_type("locals", locals, Symbol)

        @superclass_node = check_nil_or_type("superclass_node", superclass_node, Node)
        @namespace_node  = check_nil_or_type("namespace_node", namespace_node, Node)
        @body = check_type("body", body, Node)
      end

      def to_s
        "class(#{@name}, locals: #{@locals} body: #{@body})"
      end

      def evaluate(context)
        if @namespace_node
          # Namespaced class: class A::B — define B inside A
          # The namespace A is NOT pushed onto the lexical scope stack; only B is.
          container = @namespace_node.evaluate(context)
          namespace = container.is_a?(Vm::ModuleObject) ? container : nil
          class_constant = container.get_constant(@name)
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise "previous defn of #{@name} was not a class"
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            container.set_constant(@name, class_constant)
          end
        else
          # Namespace is the innermost enclosing class/module, except at top level where
          # scopes.last is OBJECT_CLASS acting as a container, not a real nesting namespace.
          namespace = context.scopes.last.equal?(Vm::Core::OBJECT_CLASS) ? nil : context.scopes.last

          # 1. find or create the class defn and constant
          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          class_constant = context.scopes.last.get_constant(@name)
          unless class_constant.nil? or class_constant.is_a?(Vm::ClassObject)
            # TODO this is a real runtime error, not an assert
            raise "previous defn of #{@name} was not a class"
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            context.scopes.last.set_constant(@name, class_constant)
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
