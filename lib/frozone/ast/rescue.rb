require_relative 'node'
require_relative '../vm/frozone_exception'

module Frozone
  module Ast
    # A single rescue clause: rescue ExcClass, ... => var; body
    class RescueClause
      attr_reader :exception_nodes, :var_name, :var_depth, :assign_node, :body

      def initialize(exception_nodes, var_name, var_depth, body, assign_node: nil)
        @exception_nodes = exception_nodes  # Array<Node> — empty means catch-all
        @var_name    = var_name             # Symbol or nil (for local var target)
        @var_depth   = var_depth            # Integer or nil
        @assign_node = assign_node          # Node or nil (for ivar/gvar targets)
        @body = body
      end

      # Does this clause match the given host-Ruby exception in context?
      def matches?(e, context)
        # bare rescue catches StandardError and subclasses (not Exception)
        if @exception_nodes.empty?
          std_error = Vm::Core::OBJECT_CLASS.get_constant(:StandardError)
          return std_error ? exception_matches?(e, std_error, context) : true
        end

        @exception_nodes.any? do |exc_node|
          frozone_class = exc_node.evaluate(context)
          # Splatted rescue list: *[ExcA, ExcB] evaluates to an ArrayObject
          if frozone_class.is_a?(Vm::ArrayObject)
            frozone_class.raw.any? { |fc| exception_matches?(e, fc, context) }
          else
            exception_matches?(e, frozone_class, context)
          end
        end
      end

      private

      # Check whether exception e matches frozone_class using ===.
      def exception_matches?(e, frozone_class, context)
        # Ruby raises TypeError for non-Module/Class rescue clauses
        unless frozone_class.is_a?(Vm::ClassObject) || frozone_class.is_a?(Vm::ModuleObject)
          raise Vm::FrozoneException.make(:TypeError, "class or module required for rescue clause")
        end

        vm_obj = e.is_a?(Vm::FrozoneException) ? e.vm_object : nil

        # Try VM dispatch of === if frozone_class is a VM object with dispatch
        if frozone_class.respond_to?(:dispatch) && vm_obj
          begin
            result = frozone_class.dispatch(context, :===, [vm_obj], {}, nil, private_ok: true)
            return result.truthy?
          rescue Vm::FrozoneException
            raise
          rescue
            # fall through to class hierarchy check
          end
        end

        # Fallback: walk the class hierarchy
        exception_is_a?(e, frozone_class)
      end

      # Check whether exception e is an instance of (or subclass of) frozone_class.
      def exception_is_a?(e, frozone_class)
        frozone_name = frozone_class.respond_to?(:name) ? frozone_class.name : nil

        if e.is_a?(Vm::FrozoneException)
          vm_obj = e.vm_object
          # Walk the class hierarchy of the VM exception object.
          c = vm_obj.is_a?(Vm::ObjectObject) ? vm_obj.class_object : nil
          while c
            return true if c.equal?(frozone_class)
            c = c.respond_to?(:superclass) ? c.superclass : nil
          end
          return false
        end

        # Plain Ruby exception (not wrapped in FrozoneException) —
        # match if frozone_class is Exception or a Ruby ancestor.
        return false unless frozone_name
        ruby_exc_names = RUBY_EXCEPTION_ANCESTORS[e.class]
        ruby_exc_names&.include?(frozone_name)
      end

      # Map Ruby exception classes to their ancestor chain names (for rescue matching)
      RUBY_EXCEPTION_ANCESTORS = Hash.new { |h, k|
        h[k] = k.ancestors.map { |a| a.name&.to_sym }.compact
      }
    end

    class Rescue < Node
      # Control-flow exceptions must never be intercepted by user rescue clauses.
      CONTROL_FLOW = [ReturnException, NextException, RedoException, BreakException, RetryException].freeze

      def initialize(body, rescue_clauses, else_node, ensure_node)
        @body           = body
        @rescue_clauses = rescue_clauses  # Array<RescueClause>
        @else_node      = else_node
        @ensure_node    = ensure_node
      end

      def evaluate(context)
        rescued = false
        result  = nil
        retry_requested = false

        loop do
          retry_requested = false
          rescued = false
          begin
            result = @body.evaluate(context)
          rescue => e
            raise if CONTROL_FLOW.any? { |k| e.is_a?(k) }

            # Set $! immediately so rescue clause expressions see the current exception
            # (e.g. `rescue (raise "other")` needs $! set for cause to be correct)
            vm_val = e.is_a?(Vm::FrozoneException) ? e.vm_object : Vm::FrozoneException.wrap_mri(e)
            prev_dollar_bang = Vm::GLOBALS[:"$!"]
            prev_dollar_at = Vm::GLOBALS[:"$@"]
            Vm::GLOBALS[:"$!"] = vm_val
            existing_bt = vm_val.get_ivar(:@backtrace) rescue nil
            bt_for_dollar_at = (existing_bt.is_a?(Vm::ArrayObject) && !existing_bt.raw.empty?) ? existing_bt : Vm::ArrayObject.new([])
            Vm::GLOBALS[:"$@"] = bt_for_dollar_at

            begin
              clause = @rescue_clauses.find { |c| c.matches?(e, context) }
            rescue => clause_err
              # Exception raised during rescue clause expression evaluation
              # (e.g. `rescue (raise "other")`). Restore $! before re-raising.
              Vm::GLOBALS[:"$!"] = prev_dollar_bang || Vm::NilObject::NIL
              Vm::GLOBALS[:"$@"] = prev_dollar_at || Vm::NilObject::NIL
              raise clause_err
            end
            unless clause
              Vm::GLOBALS[:"$!"] = prev_dollar_bang || Vm::NilObject::NIL
              Vm::GLOBALS[:"$@"] = prev_dollar_at || Vm::NilObject::NIL
              raise
            end

            rescued = true
            if clause.var_name
              context.frame.frame_at_depth(clause.var_depth).set_local(clause.var_name, vm_val)
            elsif clause.assign_node
              clause.assign_node.store(context, vm_val)
            end
            begin
              result = clause.body.evaluate(context)
            rescue RetryException
              retry_requested = true
            rescue Vm::FrozoneException
              raise
            rescue => body_exc
              raise if CONTROL_FLOW.any? { |k| body_exc.is_a?(k) }
              # Native MRI exception raised inside rescue body — wrap it and set cause.
              wrapped = Vm::FrozoneException.wrap_mri(body_exc)
              current_exc = Vm::GLOBALS[:"$!"]
              if current_exc && !current_exc.is_a?(Vm::NilObject) && !current_exc.equal?(wrapped)
                (wrapped.set_ivar(:@cause, current_exc)) rescue nil
              end
              raise Vm::FrozoneException.new(wrapped, body_exc.message)
            ensure
              Vm::GLOBALS[:"$!"] = prev_dollar_bang || Vm::NilObject::NIL
              Vm::GLOBALS[:"$@"] = prev_dollar_at || Vm::NilObject::NIL
            end
          else
            result = @else_node.evaluate(context) if @else_node
          ensure
            if @ensure_node
              # When an exception is propagating through this ensure (unrescued or re-raised),
              # Ruby sets $! to that exception. Mirror this in our Vm::GLOBALS[:"$!"].
              propagating = $!
              if propagating && !CONTROL_FLOW.any? { |k| propagating.is_a?(k) }
                vm_exc = Vm::FrozoneException.wrap_mri(propagating)
                prev_exc = Vm::GLOBALS[:"$!"]
                Vm::GLOBALS[:"$!"] = vm_exc
                begin
                  @ensure_node.evaluate(context)
                ensure
                  Vm::GLOBALS[:"$!"] = prev_exc
                end
              else
                @ensure_node.evaluate(context)
              end
            end
          end
          break unless retry_requested
        end

        result
      end
    end
  end
end
