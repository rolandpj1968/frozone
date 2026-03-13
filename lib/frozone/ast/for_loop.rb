require_relative 'node'
require_relative '../vm/native_block'
require_relative '../vm/globals'

module Frozone
  module Ast
    # for x in collection; body; end
    # For loops do NOT create a new scope - iteration variables persist in the enclosing scope.
    # @target is one of:
    #   [:local,    name_sym]                       - single local variable
    #   [:ivar,     name_sym]                       - instance variable
    #   [:cvar,     name_sym]                       - class variable
    #   [:gvar,     name_sym]                       - global variable
    #   [:constant, name_sym]                       - constant
    #   [:multi, lefts, rest_sym_or_nil, rights]  - multi-target destructuring
    #   [:call,  receiver_node, write_name]       - method call target (ofor.target)
    #   [:index, receiver_node, [arg_nodes]]      - index target (arr[1])
    class ForLoop < Node
      def initialize(target, collection_node, body_node)
        @target = target
        @collection_node = collection_node
        @body_node = body_node
      end

      def evaluate(context)
        collection = @collection_node.evaluate(context)
        enclosing_frame = context.frame

        # Collect all yielded arg-lists by calling each with a native block.
        # We store raw arg arrays so we can apply proper Ruby for-loop binding rules.
        all_args = []
        collector = Vm::NativeBlock.new { |_ctx, args| all_args << args }

        begin
          collection.dispatch(context, :each, [], {}, collector)
        rescue Ast::BreakException => e
          return e.value
        end

        # Iterate directly in the enclosing frame (no new scope for for loops).
        all_args.each do |args|
          assign_target(context, enclosing_frame, args)
          # Support redo: re-run body with same args (don't re-assign target)
          loop do
            begin
              @body_node.evaluate(context)
              break
            rescue Ast::BreakException => e
              return e.value
            rescue Ast::NextException
              break
            rescue Ast::RedoException
              # redo: re-run body with same iteration variable values
            end
          end
        end

        collection
      end

      private

      # args is a raw Ruby Array of VM objects (the values yielded by each)
      def assign_target(context, frame, args)
        case @target[0]
        when :local, :ivar, :cvar, :gvar, :constant
          # Single target: Ruby for-loop takes only the first yielded value
          value = args.fetch(0, Vm::NilObject::NIL)
          case @target[0]
          when :local    then frame.set_local(@target[1], value)
          when :ivar     then frame.the_self.set_ivar(@target[1], value)
          when :cvar
            klass = frame.the_self.is_a?(Vm::ModuleObject) ? frame.the_self : frame.the_self.class_object
            klass.set_class_var(@target[1], value)
          when :gvar     then Vm::GLOBALS[@target[1]] = value
          when :constant
            scope = frame.scopes.last
            Vm::emit_warning(context, "already initialized constant #{@target[1]}") if scope.get_constant(@target[1])
            scope.set_constant(@target[1], value)
          end
        when :call
          _, receiver_node, write_name, safe_nav = @target
          value = args.fetch(0, Vm::NilObject::NIL)
          receiver = receiver_node.evaluate(context)
          receiver.dispatch(context, write_name, [value], {}) unless safe_nav && receiver.is_a?(Vm::NilObject)
        when :index
          _, receiver_node, arg_nodes = @target
          value = args.fetch(0, Vm::NilObject::NIL)
          receiver = receiver_node.evaluate(context)
          indices = arg_nodes.map { |n| n.evaluate(context) }
          receiver.dispatch(context, :[]=, indices + [value], {})
        when :multi
          _, lefts, rest_sym, rights = @target
          # Multi-target: if 1 yielded arg, treat it as the array to destructure;
          # if multiple yielded args, treat all args as the array.
          item = args.length == 1 ? args[0] : Vm::ArrayObject.new(args)
          arr = item.is_a?(Vm::ArrayObject) ? item.raw : [item]
          n_lefts  = lefts.length
          n_rights = rights.length
          n_rest   = [arr.length - n_lefts - n_rights, 0].max

          lefts.each_with_index do |name, idx|
            frame.set_local(name, arr.fetch(idx, Vm::NilObject::NIL))
          end

          unless rest_sym.nil?
            rest_items = arr[n_lefts, n_rest] || []
            frame.set_local(rest_sym, Vm::ArrayObject.new(rest_items))
          end

          rights.each_with_index do |name, idx|
            pos = arr.length - n_rights + idx
            frame.set_local(name, pos >= 0 ? (arr[pos] || Vm::NilObject::NIL) : Vm::NilObject::NIL)
          end
        end
      end
    end
  end
end
