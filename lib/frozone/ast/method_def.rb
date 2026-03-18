require_relative 'node'
require_relative '../vm/method'
require_relative '../vm/symbol_object'

module Frozone
  module Ast
    class MethodDef < Node
      attr_reader :name, :receiver_node, :required_params, :optional_params, :rest_param, :post_params
      attr_reader :required_kw_params, :optional_kw_params, :kw_rest_param, :block_param, :locals, :body

      def initialize(name, receiver_node, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param, locals, body, uses_block: nil, source_location: nil)
        @name = name
        @receiver_node = receiver_node

        @required_params = required_params
        @optional_params = optional_params
        @rest_param = rest_param
        @post_params = post_params

        @required_kw_params = required_kw_params
        @optional_kw_params = optional_kw_params
        @kw_rest_param = kw_rest_param

        @block_param = block_param

        @locals = locals
        @body = body
        @uses_block = uses_block
        @source_location = source_location
      end

      def evaluate(context)
        # Determine the defining scope: def_scope from frame (set by instance_eval or Method#invoke)
        # takes priority over the lexical context.scopes.last.
        frame = context.frame
        def_scope = frame.def_scope
        frame_scopes = frame.scopes

        if @receiver_node.nil?
          # Visibility: def resets to public inside a real method body, but closures
          # (blocks/lambdas) at class-body level look outside for the current_visibility.
          inside_method = frame.method_frame&.current_method != nil
          # At class-body level (not inside a method), use the_self as defining scope.
          # This handles both `class Foo; def bar; end; end` and `Class.new { def bar; end }`.
          # Inside a method, use def_scope (set by Method#invoke to method's defining class).
          scope = if inside_method
            def_scope || frame_scopes.last
          else
            def_scope || (frame.the_self.is_a?(Vm::ModuleObject) ? frame.the_self : frame_scopes.last)
          end
          # Method's lexical scopes: use frame's scopes (definition-site), but ensure
          # the actual defining scope is included at the end (for super to work correctly).
          method_scopes = if !scope.equal?(frame_scopes.last)
            frame_scopes + [scope]
          elsif def_scope && !def_scope.equal?(frame_scopes.last)
            frame_scopes + [def_scope]
          else
            frame_scopes
          end
          method = Vm::Method.new(method_scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
          method.active_refinements = frame.active_refinements if frame.active_refinements
          private_by_default = %i[initialize initialize_copy initialize_dup initialize_clone respond_to_missing?].include?(@name)
          vis = private_by_default ? :private : (inside_method ? :public : scope.current_visibility)
          prev_call_site = context.call_site
          context.call_site = @source_location if @source_location
          if vis == :module_function
            # module_function: private instance method + public singleton method
            method.visibility = :private
            scope.set_method(@name, method)
            Vm::Intrinsics.trigger_method_added(context, scope, @name)
            # Singleton method scopes use [singleton_class] so super resolves through
            # the singleton class chain (includes extended modules).
            singleton_method = Vm::Method.new([scope.singleton_class], @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
            singleton_method.visibility = :public
            scope.singleton_class.set_method(@name, singleton_method)
            Vm::Intrinsics.trigger_method_added(context, scope.singleton_class, @name)
          else
            method.visibility = vis
            scope.set_method(@name, method)
            Vm::Intrinsics.trigger_method_added(context, scope, @name)
          end
          context.call_site = prev_call_site
        else
          # For singleton methods: `def obj.foo` or `def self.foo`
          receiver_val = @receiver_node.evaluate(context)
          # nil/true/false cannot have singleton classes: redirect to their class (MRI compat)
          if receiver_val.is_a?(Vm::NilObject) || receiver_val.is_a?(Vm::TrueObject) || receiver_val.is_a?(Vm::FalseObject)
            scope = receiver_val.class_object
            method = Vm::Method.new(frame_scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
            method.active_refinements = frame.active_refinements if frame.active_refinements
            method.visibility = vis
            scope.set_method(@name, method)
            prev_call_site = context.call_site
            context.call_site = @source_location if @source_location
            Vm::Intrinsics.trigger_method_added(context, scope, @name)
            context.call_site = prev_call_site
            return Vm::SymbolObject.from(@name)
          end
          # Integer/Float/Symbol cannot have singleton classes: raise TypeError (not FrozenError)
          if receiver_val.is_a?(Vm::IntegerObject) || receiver_val.is_a?(Vm::FloatObject) || receiver_val.is_a?(Vm::SymbolObject)
            raise Vm::FrozoneException.make(:TypeError, "can't define singleton for #{receiver_val.class_object.name}")
          end
          # Check if receiver (or its singleton class) is frozen, and raise FrozenError with correct type name
          receiver_sc = receiver_val.eigenclass
          if receiver_val.frozen_object? || (receiver_sc && receiver_sc.frozen_object?)
            if receiver_val.is_a?(Vm::ClassObject)
              type_name = "Class"
            elsif receiver_val.is_a?(Vm::ModuleObject)
              type_name = "Module"
            else
              type_name = receiver_val.class_object&.name&.to_s || "Object"
            end
            repr = begin; receiver_val.dispatch(context, :inspect, [], {}).raw; rescue StandardError; receiver_val.to_s; end
            raise Vm::FrozoneException.make(:FrozenError, "can't modify frozen #{type_name}: #{repr}", receiver: receiver_val)
          end
          method_scopes = if receiver_val.is_a?(Vm::ClassObject)
            # Class-level singleton method (def ClassName.foo / def self.foo in class body):
            # keep lexical scopes so super.rb can map ClassObject → singleton class.
            def_scope && !def_scope.equal?(frame_scopes.last) ? frame_scopes + [def_scope] : frame_scopes
          else
            # Instance-level singleton method (def obj.foo for non-class objects):
            # set defining scope to obj's singleton class so super searches from there.
            frame_scopes + [receiver_val.singleton_class]
          end
          method = Vm::Method.new(method_scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
          method.active_refinements = frame.active_refinements if frame.active_refinements
          # For instance singleton methods, nested `def` should go to the enclosing class (like MRI nesting)
          method.nested_def_scope = frame_scopes.last unless receiver_val.is_a?(Vm::ClassObject)
          receiver_val.define_singleton_method(@name, method)
          prev_call_site = context.call_site
          context.call_site = @source_location if @source_location
          Vm::Intrinsics.trigger_method_added(context, receiver_val.singleton_class, @name)
          context.call_site = prev_call_site
        end
        Vm::SymbolObject.from(@name)
      end
    end
  end
end
