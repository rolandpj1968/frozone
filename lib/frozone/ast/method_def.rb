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
          private_by_default = %i[initialize initialize_copy initialize_dup initialize_clone respond_to_missing?].include?(@name)
          vis = private_by_default ? :private : (inside_method ? :public : scope.current_visibility)
          if vis == :module_function
            # module_function: private instance method + public singleton method
            method.visibility = :private
            scope.set_method(@name, method)
            singleton_method = Vm::Method.new(method.scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
            singleton_method.visibility = :public
            scope.singleton_class.set_method(@name, singleton_method)
          else
            method.visibility = vis
            scope.set_method(@name, method)
          end
        else
          # For singleton methods: `def obj.foo` or `def self.foo`
          receiver_val = @receiver_node.evaluate(context)
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
          # For instance singleton methods, nested `def` should go to the enclosing class (like MRI nesting)
          method.nested_def_scope = frame_scopes.last unless receiver_val.is_a?(Vm::ClassObject)
          receiver_val.define_singleton_method(@name, method)
        end
        Vm::SymbolObject.from(@name)
      end
    end
  end
end
