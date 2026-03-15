module Frozone
  module Vm
    # Wraps a Symbol for use as a block (&:method_name).
    # Equivalent to { |x, *args| x.send(sym, *args) }
    class SymbolProcObject
      def initialize(symbol_obj)
        @symbol_obj = symbol_obj
      end

      def invoke(context, args, block: nil, **_kwargs)
        receiver = args[0]
        rest = args[1..]
        block_obj = block.is_a?(ProcObject) ? block.block_object : block
        block_obj = nil if block_obj.nil? || block_obj.is_a?(NilObject)
        receiver.dispatch(context, @symbol_obj.raw, rest, {}, block_obj, public_only: true)
      end

      def truthy? = true
    end
  end
end
