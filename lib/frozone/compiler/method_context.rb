# Per-method emission state for the Codegen.
#
# Created for each method (or the execute block) being emitted. Holds all
# type information and flags scoped to the current method body. Replaces
# the scattered @current_* and @typed_* ivars on the Codegen class.

require_relative 'crystal_type'

module Frozone
  module Compiler
    class MethodContext
      attr_accessor :typed_locals           # {name => :i64/:f64}
      attr_accessor :typed_array_locals     # {name => :i64/:f64} (native Array(T) elem type)
      attr_accessor :native_array_locals    # {name => :i64/:f64} (from params or 2D reads)
      attr_accessor :class_locals           # {name => class_sym} (devirtualized)
      attr_accessor :local_array_elems      # {name => :i64/:f64} (boxed array elem type)
      attr_accessor :local_2d_arrays        # {name => :i64/:f64} (inner elem of Array(Array(T)))
      attr_accessor :local_types            # {name => CrystalType} (unified)
      attr_accessor :block_params           # {name => :i64/:f64}
      attr_accessor :raw_block_params       # {name => :i64/:f64} (currently-native block params)
      attr_accessor :param_set              # Set of param names
      attr_accessor :method_body            # Ast::Node
      attr_accessor :block_param_name       # Symbol or nil
      attr_accessor :suppress_typed_call_args  # Bool
      attr_accessor :emit_crystal_tuple        # Bool

      def initialize
        @typed_locals = {}
        @typed_array_locals = {}
        @native_array_locals = {}
        @class_locals = {}
        @local_array_elems = {}
        @local_2d_arrays = {}
        @local_types = {}
        @block_params = {}
        @raw_block_params = {}
        @param_set = Set.new
        @method_body = nil
        @block_param_name = nil
        @suppress_typed_call_args = false
        @emit_crystal_tuple = false
      end

      # Is this name a parameter?
      def param?(name) = @param_set.include?(name)

      # Scalar type of a local (:i64/:f64 or nil).
      def scalar_type(name) = @typed_locals[name] || @raw_block_params[name]

      # Native flat array element type (:i64/:f64 or nil).
      # Only for locals CONSTRUCTED as native arrays.
      def native_array_elem(name) = @typed_array_locals[name] || @native_array_locals[name]

      # CrystalType of a local, or nil.
      def crystal_type(name) = @local_types[name]

      # Is this local a 2D native array?
      def local_2d?(name) = @local_2d_arrays.key?(name)

      # Inner scalar type of a 2D array local, or nil.
      def local_2d_elem(name) = @local_2d_arrays[name]
    end
  end
end
