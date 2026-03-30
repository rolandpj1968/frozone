require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ClassDef < Node
      def initialize(name, locals, superclass_node, body, namespace_node: nil, source_location: nil)
        @name = name

        @locals = locals

        @superclass_node = superclass_node
        @namespace_node = namespace_node
        @body = body
        @source_location = source_location
      end

      def children = [@namespace_node, @superclass_node, @body].compact

      def to_s = "class(#{@name}, locals: #{@locals} body: #{@body})"

      def evaluate(context)
        if @namespace_node
          # Namespaced class: class A::B — define B inside A
          # The namespace A is NOT pushed onto the lexical scope stack; only B is.
          container = @namespace_node.evaluate(context)
          raise Vm::FrozoneException.make(:TypeError, "#{@namespace_node} is not a class/module") unless container.is_a?(Vm::ModuleObject)
          namespace = container
          if container.constant_private?(@name)
            container_name = container.is_a?(Vm::ModuleObject) ? container.name : nil
            label = container_name ? "#{container_name}::#{@name}" : @name.to_s
            raise Vm::FrozoneException.make(:NameError, "private constant #{label} referenced")
          end
          class_constant = container.get_constant(@name)
          if class_constant.nil? && (autoload_path = container.lookup_autoload(@name, inherit: false))
            begin
              Vm::Intrinsics.kernel_require(context, nil, Vm::StringObject.new(autoload_path))
            rescue Vm::FrozoneException
              raise
            end
            class_constant = container.get_constant(@name)
            container.remove_autoload(@name) if class_constant.nil?
          end
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            superclass = @superclass_node ? @superclass_node.evaluate(context) : Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{superclass.class_object&.name} given)") unless superclass.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "can't make subclass of singleton class") if superclass.is_singleton_class
            class_constant = Vm::ClassObject.new(@name, namespace, superclass)
            class_constant.mark_name_permanent! if container.equal?(Vm::Core::OBJECT_CLASS) || container.name_permanent
            container.set_constant(@name, class_constant, source_location: @source_location)
            prev_call_site = context.call_site
            context.call_site = "#{@source_location[0]}:#{@source_location[1]}" if @source_location
            Vm.trigger_const_added(context, container, @name)
            context.call_site = prev_call_site
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
          if class_constant.nil? && (autoload_path = lex_scope.lookup_autoload(@name, inherit: false))
            begin
              Vm::Intrinsics.kernel_require(context, nil, Vm::StringObject.new(autoload_path))
            rescue Vm::FrozoneException
              raise
            end
            class_constant = lex_scope.get_constant(@name)
            lex_scope.remove_autoload(@name) if class_constant.nil?
          end
          unless class_constant.nil? || class_constant.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a class (#{class_constant.class_object&.name})")
          end
          if class_constant.nil?
            sc = superclass || Vm::Core::OBJECT_CLASS
            raise Vm::FrozoneException.make(:TypeError, "superclass must be a Class (#{sc.class_object&.name} given)") unless sc.is_a?(Vm::ClassObject)
            raise Vm::FrozoneException.make(:TypeError, "can't make subclass of singleton class") if sc.is_singleton_class
            class_constant = Vm::ClassObject.new(@name, namespace, sc)
            class_constant.mark_name_permanent! if lex_scope.equal?(Vm::Core::OBJECT_CLASS) || lex_scope.name_permanent
            lex_scope.set_constant(@name, class_constant, source_location: @source_location)
            prev_call_site = context.call_site
            context.call_site = "#{@source_location[0]}:#{@source_location[1]}" if @source_location
            Vm.trigger_const_added(context, lex_scope, @name)
            context.call_site = prev_call_site
            dispatch_inherited(context, sc, class_constant)
          elsif @superclass_node
            raise Vm::FrozoneException.make(:TypeError, "superclass mismatch for class #{@name}") unless class_constant.superclass.equal?(superclass)
          end
        end

        context.scopes << class_constant
        prev_visibility = class_constant.current_visibility
        class_constant.current_visibility = :public
        new_frame = Vm::Frame.new(class_constant, @locals, context.scopes)
        # Inherit active refinements from the enclosing frame (lexical scoping of `using`)
        new_frame.active_refinements = context.frame.active_refinements if context.frame.active_refinements
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
        superclass.dispatch(context, :inherited, [subclass], {}, nil, private_ok: true)
      rescue Vm::FrozoneException => e
        raise unless e.frozone_class_name == :NoMethodError
      end
    end
  end
end
