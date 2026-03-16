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
          if container.constant_private?(@name)
            container_name = container.respond_to?(:name) ? container.name : nil
            label = container_name ? "#{container_name}::#{@name}" : @name.to_s
            raise Vm::FrozoneException.make(:NameError, "private constant #{label} referenced")
          end
          class_constant = container.get_constant(@name)
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{superclass.class_object&.name} given)") unless superclass.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "can't make subclass of singleton class") if superclass.is_singleton_class
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            container.set_constant(@name, class_constant)
            dispatch_inherited(context, superclass, class_constant)
          elsif @superclass_node
            superclass = @superclass_node.evaluate(context)
            raise Vm::FrozoneException.make(:TypeError, "superclass mismatch for class #{@name}") unless class_constant.superclass.equal?(superclass)
          end
        else
          # Use the LEXICAL scope (frame's definition-site scopes) for constant lookup/assignment.
          # This ensures that `class Foo` inside a block/lambda uses the block's outer scope,
          # not the dynamic scope at call time.
          lex_scope = context.frame.scopes.last

          # Namespace is the innermost enclosing class/module, except at top level where
          # scopes.last is OBJECT_CLASS acting as a container, not a real nesting namespace.
          namespace = lex_scope.equal?(Vm::Core::OBJECT_CLASS) ? nil : lex_scope

          # 1. Evaluate superclass expression FIRST (Ruby evaluates it before checking constant)
          superclass = @superclass_node ? @superclass_node.evaluate(context) : nil

          # 2. Find or create the class constant
          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          class_constant = lex_scope.get_constant(@name)
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            sc = superclass || Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{sc.class_object&.name} given)") unless sc.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "can't make subclass of singleton class") if sc.is_singleton_class
            class_constant = Vm::ClassObject.new(@name, namespace, sc)
            lex_scope.set_constant(@name, class_constant)
            dispatch_inherited(context, sc, class_constant)
          elsif @superclass_node
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

      private

      def dispatch_inherited(context, superclass, subclass)
        m = superclass.lookup_instance_method(:inherited)
        return if m.nil?
        superclass.dispatch(context, :inherited, [subclass], {}, nil)
      end
    end
  end
end
