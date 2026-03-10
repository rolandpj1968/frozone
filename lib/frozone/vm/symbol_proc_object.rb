module Frozone
  module Vm
    # Wraps a Symbol for use as a block (&:method_name).
    # Equivalent to { |x, *args| x.send(sym, *args) }
    class SymbolProcObject
      def initialize(symbol_obj)
        @symbol_obj = symbol_obj
      end

      def invoke(context, args)
        receiver = args[0]
        rest = args[1..]
        receiver.dispatch(context, @symbol_obj.raw, rest, {})
      end

      def truthy? = true
    end
  end
end
