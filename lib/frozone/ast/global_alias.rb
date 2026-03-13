require_relative 'node'
require_relative '../vm/globals'

module Frozone
  module Ast
    class GlobalAlias < Node
      def initialize(new_name, old_name)
        @new_name = new_name
        @old_name = old_name
      end

      def evaluate(_context)
        # Resolve the canonical name of old_name (follow existing aliases)
        canonical = Vm::GLOBAL_ALIASES.fetch(@old_name, @old_name)
        Vm::GLOBAL_ALIASES[@new_name] = canonical
        Vm::NilObject::NIL
      end
    end
  end
end
