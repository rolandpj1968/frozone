require_relative 'node'
require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ModuleDef < Node
      def initialize(name, locals, body, namespace_node: nil, source_location: nil)
        @name = name

        @locals = locals

        @namespace_node = namespace_node
        @body = body
        @source_location = source_location
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
            container_name = container.is_a?(Vm::ModuleObject) ? container.name : nil
            label = container_name ? "#{container_name}::#{@name}" : @name.to_s
            raise Vm::FrozoneException.make(:NameError, "private constant #{label} referenced")
          end
          module_constant = container.get_constant(@name)
          if module_constant.nil? && (autoload_path = container.lookup_autoload(@name, inherit: false))
            begin
              Vm::Intrinsics.kernel_require(context, nil, Vm::StringObject.new(autoload_path))
            rescue Vm::FrozoneException
              raise
            end
            module_constant = container.get_constant(@name)
            container.remove_autoload(@name) if module_constant.nil?
          end
          unless module_constant.nil? || (module_constant.is_a?(Vm::ModuleObject) && !module_constant.is_a?(Vm::ClassObject))
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a module (#{module_constant.is_a?(Vm::ObjectObject) ? module_constant.class_object&.name : module_constant.class} given)")
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            module_constant.mark_name_permanent! if container.equal?(Vm::Core::OBJECT_CLASS) || container.name_permanent
            container.set_constant(@name, module_constant, source_location: @source_location)
            prev_call_site = context.call_site
            context.call_site = "#{@source_location[0]}:#{@source_location[1]}" if @source_location
            Vm.trigger_const_added(context, container, @name)
            context.call_site = prev_call_site
          end
        else
          # Use the LEXICAL scope (frame's definition-site scopes) for constant lookup/assignment.
          lex_scope = context.frame.scopes.last
          namespace = lex_scope.equal?(Vm::Core::OBJECT_CLASS) ? nil : lex_scope

          # MRI only looks in the immediate enclosing class/module, not outer nesting or superclass chain.
          module_constant = lex_scope.get_constant(@name)
          if module_constant.nil? && (autoload_path = lex_scope.lookup_autoload(@name, inherit: false))
            begin
              Vm::Intrinsics.kernel_require(context, nil, Vm::StringObject.new(autoload_path))
            rescue Vm::FrozoneException
              raise
            end
            module_constant = lex_scope.get_constant(@name)
            lex_scope.remove_autoload(@name) if module_constant.nil?
          end
          unless module_constant.nil? || (module_constant.is_a?(Vm::ModuleObject) && !module_constant.is_a?(Vm::ClassObject))
            raise Vm::FrozoneException.make(:TypeError, "#{@name} is not a module (#{module_constant.is_a?(Vm::ObjectObject) ? module_constant.class_object&.name : module_constant.class} given)")
          end
          if module_constant.nil?
            module_constant = Vm::ModuleObject.new(@name, namespace)
            module_constant.mark_name_permanent! if lex_scope.equal?(Vm::Core::OBJECT_CLASS) || lex_scope.name_permanent
            lex_scope.set_constant(@name, module_constant, source_location: @source_location)
            prev_call_site = context.call_site
            context.call_site = "#{@source_location[0]}:#{@source_location[1]}" if @source_location
            Vm.trigger_const_added(context, lex_scope, @name)
            context.call_site = prev_call_site
          end
        end

        context.scopes << module_constant
        prev_visibility = module_constant.current_visibility
        module_constant.current_visibility = :public
        new_frame = Vm::Frame.new(module_constant, @locals, context.scopes)
        # Inherit active refinements from the enclosing frame (lexical scoping of `using`)
        new_frame.active_refinements = context.frame.active_refinements if context.frame.active_refinements
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
