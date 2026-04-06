# Per-method emission state for the Codegen.
#
# Created fresh for each method/execute-block emission. All per-method
# type information and flags live here — no @current_* or @typed_* ivars
# on the Codegen class.

module Frozone
  module Compiler
    class MethodContext
      attr_accessor :typed_locals # {name => Type} — scalar unboxing (Type::I64/Type::F64)
      attr_accessor :typed_array_locals # {name => Type} — native Array(T) from TI
      attr_accessor :native_array_locals # {name => Type} — native Array(T) from params/nested detection
      attr_accessor :class_locals # {name => class_sym} — devirtualized class-typed locals
      attr_accessor :local_array_elems # {name => Type} — boxed RubyArray elem type
      attr_accessor :local_types # {name => Type} — unified type map
      attr_accessor :block_params # {name => Type} — block param types from TI
      attr_accessor :raw_block_params # {name => Type} — currently-active native block params
      attr_accessor :param_set # Set of param names
      attr_accessor :method_body # Ast::Node — the method body AST
      attr_accessor :block_param_name # Symbol or nil — &block param name
      attr_accessor :suppress_typed_call_args # Bool — disable typed call args in generic overloads
      attr_accessor :emit_crystal_tuple # Bool — emit Crystal tuple for return array literal
      attr_accessor :suppress_tuple_literals # Bool — suppress RubyTupleN for array locals (may be mutated)

      def initialize
        @typed_locals = {}
        @typed_array_locals = {}
        @native_array_locals = {}
        @class_locals = {}
        @local_array_elems = {}
        @local_types = {}
        @block_params = {}
        @raw_block_params = {}
        @param_set = Set.new
        @method_body = nil
        @block_param_name = nil
        @suppress_typed_call_args = false
        @emit_crystal_tuple = false
        @suppress_tuple_literals = false
      end

      def param?(name) = @param_set.include?(name)

      # Native flat array element type (Type::I64/Type::F64) or nil.
      # Only for locals CONSTRUCTED as native arrays — not all array-typed locals.
      def native_array_elem(name) = @typed_array_locals[name] || @native_array_locals[name]
    end
  end
end
