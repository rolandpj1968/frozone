require_relative 'node'

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
        return true if @exception_nodes.empty?  # bare rescue

        @exception_nodes.any? do |exc_node|
          frozone_class = exc_node.evaluate(context)
          exception_is_a?(e, frozone_class)
        end
      end

      private

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
        @body           = check_type("body", body, Node)
        @rescue_clauses = rescue_clauses  # Array<RescueClause>
        @else_node      = check_nil_or_type("else_node", else_node, Node)
        @ensure_node    = check_nil_or_type("ensure_node", ensure_node, Node)
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

            clause = @rescue_clauses.find { |c| c.matches?(e, context) }
            raise unless clause

            rescued = true
            vm_val = e.is_a?(Vm::FrozoneException) ? e.vm_object : Vm::StringObject.new(e.message)
            if clause.var_name
              context.frame.frame_at_depth(clause.var_depth).set_local(clause.var_name, vm_val)
            elsif clause.assign_node
              clause.assign_node.store(context, vm_val)
            end
            begin
              result = clause.body.evaluate(context)
            rescue RetryException
              retry_requested = true
            end
          ensure
            @ensure_node&.evaluate(context)
          end
          break unless retry_requested
        end

        !rescued && @else_node ? @else_node.evaluate(context) : result
      end
    end
  end
end
