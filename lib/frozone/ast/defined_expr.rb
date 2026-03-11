require_relative 'node'

module Frozone
  module Ast
    # defined?(expr) — returns a String describing what expr is, or nil
    class DefinedExpr < Node
      def initialize(kind, extra = nil)
        @kind  = kind   # Symbol: :self, :nil, :true, :false, :literal, :constant,
                        #         :local_var, :ivar, :cvar, :gvar, :method, :yield, :super
        @extra = extra  # varies by kind
      end

      def evaluate(context)
        result = case @kind
        when :self       then "self"
        when :nil        then "nil"
        when :true       then "true"
        when :false      then "false"
        when :literal    then "expression"
        when :assignment then "assignment"
        when :expression then "expression"
        when :constant
          # @extra is the AST node to evaluate the constant lookup
          begin
            @extra.evaluate(context)
            "constant"
          rescue Vm::FrozoneException => e
            nil
          end
        when :local_var
          # Always defined at this point (Prism only generates defined?(local) if in scope)
          "local-variable"
        when :ivar
          val = context.frame.the_self.get_ivar(@extra)
          val && !val.is_a?(Vm::NilObject) ? "instance-variable" : nil
        when :cvar
          # @extra is class var name
          begin
            klass = context.scopes.last
            val = klass.get_class_var(@extra)
            val ? "class variable" : nil
          rescue
            nil
          end
        when :gvar
          # global-variable is defined if it's been assigned (even to nil)
          Vm::GLOBALS.key?(@extra) ? "global-variable" : nil
        when :method
          # @extra = [receiver_node_or_nil, method_name]
          receiver_node, method_name = @extra
          if receiver_node
            begin
              receiver = receiver_node.evaluate(context)
              method = receiver.class_object.lookup_method(method_name)
              method ? "method" : nil
            rescue
              nil
            end
          else
            # Implicit receiver — check current self
            receiver = context.frame.the_self
            method = receiver.class_object.lookup_method(method_name)
            method ? "method" : nil
          end
        when :yield
          context.frame.block ? "yield" : nil
        when :super
          mf = context.frame.method_frame
          return nil unless mf
          current_method = mf.current_method
          return nil unless current_method
          method_name    = current_method.name
          defining_class = current_method.scopes.last
          receiver = context.frame.the_self
          klass = receiver.is_a?(Vm::ClassObject) ? receiver.singleton_class : receiver.class_object
          origin = receiver.is_a?(Vm::ClassObject) ? defining_class.singleton_class : defining_class
          super_method = klass.lookup_method_after(method_name, origin)
          super_method ? "super" : nil
        end

        result ? Vm::StringObject.new(result, frozen: true) : Vm::NilObject::NIL
      end
    end
  end
end
