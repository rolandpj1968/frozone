module Frozone
  module Vm
    # Wraps a Symbol for use as a block (&:method_name).
    # Equivalent to { |x, *args| x.send(sym, *args) }
    class SymbolProcObject
      def initialize(symbol_obj, active_refinements: nil)
        @symbol_obj = symbol_obj
        # Capture refinements active at creation site so that Symbol#to_proc
        # honors refinements from the call site (e.g. `map(&:to_s)` with `using` active).
        @active_refinements = active_refinements
      end

      def symbol_name = @symbol_obj.raw

      def invoke(context, args, block: nil, **_kwargs)
        raise FrozoneException.make(:ArgumentError, "no receiver given") if args.empty?
        receiver = args[0]
        rest = args[1..]
        block_obj = block.is_a?(ProcObject) ? block.block_object : block
        block_obj = nil if block_obj.nil? || block_obj.is_a?(NilObject)
        # Temporarily apply captured refinements to the current frame for this dispatch.
        if @active_refinements && !@active_refinements.empty?
          frame = context.frame
          prev_refs = frame&.active_refinements
          unless prev_refs && !prev_refs.empty?
            frame&.active_refinements = @active_refinements
            begin
              return receiver.dispatch(context, @symbol_obj.raw, rest, {}, block_obj, public_only: true)
            ensure
              frame&.active_refinements = prev_refs
            end
          end
        end
        receiver.dispatch(context, @symbol_obj.raw, rest, {}, block_obj, public_only: true)
      end

      def truthy? = true
    end
  end
end
