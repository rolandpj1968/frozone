require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ClassDef < Node
      def initialize(name, locals, superclass_node, body)
        @name = check_type("name", name, Symbol)

        raise "class defn with locals not yet supported" unless locals.empty?
        @locals = check_array_type("locals", locals, Symbol)

        @superclass_node = check_nil_or_type("superclass_node", superclass_node, Node)
        @body = check_type("body", body, Node)
      end

      def to_s
        "class(#{@name}, locals: #{@locals} body: #{@body})"
      end

      def evaluate(context)
        # Namespace is the innermost enclosing class/module, except at top level where
        # scopes.last is OBJECT_CLASS acting as a container, not a real nesting namespace.
        namespace = context.scopes.last.equal?(Vm::Core::OBJECT_CLASS) ? nil : context.scopes.last

        # 1. find or create the class defn and constant
        class_constant = Vm::ModuleObject.lookup_constant(@name, context.scopes)
        unless class_constant.nil? or class_constant.is_a?(Vm::ClassObject)
          # TODO this is a real runtime error, not an assert
          raise "previous defn of #{@name} was not a class"
        end
        if class_constant.nil?
          superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
          class_constant = Vm::ClassObject.new(@name, namespace, superclass)
          context.scopes.last.set_constant(@name, class_constant)
        end

        context.scopes << class_constant
        class_constant.current_visibility = :public
        new_frame = Vm::Frame.new(class_constant, @locals, context.scopes)
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
