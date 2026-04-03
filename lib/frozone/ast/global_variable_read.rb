require_relative 'node'
require_relative '../vm/globals'

module Frozone
  module Ast
    class GlobalVariableRead < Node
      attr_reader :name
      def initialize(name, no_warn: false)
        @name = name
        @no_warn = no_warn
      end

      def to_s = "gvar(#{@name})"

      def evaluate(context)
        case @name
        when :"$@"
          bang = Vm::GLOBALS.fetch(:"$!", Vm::NilObject::NIL)
          bang.is_a?(Vm::NilObject) ? Vm::NilObject::NIL : Vm::GLOBALS.fetch(:"$@", Vm::NilObject::NIL)
        when :"$="
          Vm::emit_warning(context, "variable $= is no longer effective")
          Vm::GLOBALS.fetch(:"$=", Vm::NilObject::NIL)
        when :"$-0"
          Vm::GLOBALS.fetch(:"$/", Vm::NilObject::NIL)
        when :"$-d"
          Vm::GLOBALS.fetch(:"$DEBUG", Vm::FalseObject::FALSE)
        when :"$-v", :"$-w"
          Vm::GLOBALS.fetch(:"$VERBOSE", Vm::FalseObject::FALSE)
        when :"$:", :"$-I"
          Vm::GLOBALS.fetch(:"$LOAD_PATH", Vm::NilObject::NIL)
        when :"$\""
          Vm::GLOBALS.fetch(:"$LOADED_FEATURES", Vm::NilObject::NIL)
        else
          canonical = Vm::GLOBAL_ALIASES.fetch(@name, @name)
          unless @no_warn || Vm::GLOBALS.key?(canonical)
            verbose = Vm::GLOBALS.fetch(:"$VERBOSE", Vm::FalseObject::FALSE)
            if verbose.truthy?
              Vm::emit_warning(context, "global variable `#{@name}' not initialized")
            end
          end
          Vm::GLOBALS.fetch(canonical, Vm::NilObject::NIL)
        end
      end
    end
  end
end
