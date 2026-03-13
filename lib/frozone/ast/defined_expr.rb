require_relative 'node'

module Frozone
  module Ast
    # defined?(expr) — returns a String describing what expr is, or nil
    class DefinedExpr < Node
      attr_reader :kind

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
        when :array_literal
          all_defined = @extra.all? { |check| !check.evaluate(context).is_a?(Vm::NilObject) }
          all_defined ? "expression" : nil
        when :constant
          # @extra is the AST node to evaluate the constant lookup.
          # Use defined_check? if available to avoid triggering const_missing.
          if @extra.respond_to?(:defined_check?)
            @extra.defined_check?(context) ? "constant" : nil
          else
            begin
              @extra.evaluate(context)
              "constant"
            rescue Vm::FrozoneException
              nil
            end
          end
        when :local_var
          # Always defined at this point (Prism only generates defined?(local) if in scope)
          "local-variable"
        when :ivar
          context.frame.the_self.ivar_defined?(@extra) ? "instance-variable" : nil
        when :cvar
          # @extra is class var name
          begin
            s = context.frame.the_self
            klass = s.is_a?(Vm::ModuleObject) ? s : s.class_object
            val = klass.get_class_var(@extra)
            val ? "class variable" : nil
          rescue
            nil
          end
        when :gvar
          # $! and $~ are always defined (special-cased by Ruby)
          # Other globals: defined if assigned (even to nil)
          always_defined = %i[$! $~]
          if always_defined.include?(@extra) || Vm::GLOBALS.key?(@extra)
            "global-variable"
          else
            nil
          end
        when :back_ref
          # $&, $', $`, $+ — defined only if last match was successful
          Fiber[:last_match] ? "global-variable" : nil
        when :num_ref
          # $1, $2, ... — defined only if last match captured that group
          m = Fiber[:last_match]
          (m && @extra <= m.size - 1 && m[@extra]) ? "global-variable" : nil
        when :method
          # @extra = [receiver_node_or_nil, method_name, receiver_defined_check]
          receiver_node, method_name, receiver_defined = @extra
          if receiver_node
            # If receiver might not be defined (ivar/gvar/cvar/back_ref/num_ref), check first
            receiver_ok = true
            if receiver_defined&.is_a?(DefinedExpr) &&
               %i[ivar cvar gvar back_ref num_ref].include?(receiver_defined.kind)
              recv_check = receiver_defined.evaluate(context)
              receiver_ok = !recv_check.is_a?(Vm::NilObject)
            end
            if receiver_ok
              begin
                receiver = receiver_node.evaluate(context)
                # Use respond_to? dispatch: public methods only for explicit receivers,
                # also handles class methods (via eigenclass) and respond_to_missing?
                sym = Vm::SymbolObject.from(method_name)
                result = receiver.dispatch(context, :respond_to?, [sym], {})
                result.truthy? ? "method" : nil
              rescue
                nil
              end
            end
          else
            # Implicit receiver — private methods are accessible with no receiver
            receiver = context.frame.the_self
            begin
              sym = Vm::SymbolObject.from(method_name)
              result = receiver.dispatch(context, :respond_to?, [sym, Vm::TrueObject::TRUE], {})
              result.truthy? ? "method" : nil
            rescue
              receiver.lookup_instance_method(method_name) ? "method" : nil
            end
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
