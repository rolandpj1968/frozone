# Whole-program type information for the Codegen.
#
# Populated once from CrystalTypeMapper after type inference runs.
# Read-only during emission — all per-method lookups index into these maps.

module Frozone
  module Compiler
    class GlobalContext
      attr_accessor :user_class_names # Set of user-defined class name symbols
      attr_accessor :locals # {mkey => {name => Type}} — scalar unboxing (Type::I64/F64)
      attr_accessor :arrays # {mkey => {name => Type}} — native Array(T) elem type from TI
      attr_accessor :class_locals # {mkey => {name => class_sym}} — devirtualized locals
      attr_accessor :local_array_elems # {mkey => {name => Type}} — boxed RubyArray elem type
      attr_accessor :local_types # {mkey => {name => Type}} — unified type map
      attr_accessor :block_params # {mkey => {name => Type}} — block param types from TI
      attr_accessor :class_params # {[class, method] => [Type]} — class method param types
      attr_accessor :inferred_params # {method => [Type]} — top-level method param types
      attr_accessor :typed_params # {method => [Type]} — fully raw-typed params (Type::I64/F64)
      attr_accessor :typed_method_returns # {method => Type} — raw return types (Type::I64/F64)
      attr_accessor :instance_method_raw_returns # {[class, method] => Type}
      attr_accessor :const_raw_types # {name => Type} — Type::I64/F64/ARRAY_I64/ARRAY_F64
      attr_accessor :inferred_kw_params # {mkey => {name => Type}} — keyword param types
      attr_accessor :typed_ivars # {class => {ivar => Type}} — scalar / array-scalar ivars
      attr_accessor :class_typed_ivars # {class => {ivar => [:kind, :Class]}} — class-typed ivars

      def initialize
        @user_class_names = Set.new
        @locals = {}
        @arrays = {}
        @class_locals = {}
        @local_array_elems = {}
        @local_types = {}
        @block_params = {}
        @class_params = {}
        @inferred_params = {}
        @typed_params = {}
        @typed_method_returns = {}
        @instance_method_raw_returns = {}
        @const_raw_types = {}
        @inferred_kw_params = {}
        @typed_ivars = {}
        @class_typed_ivars = {}
      end

      # Populate from a CrystalTypeMapper after type inference.
      def load_from_mapper!(mapper)
        @user_class_names = mapper.user_class_names
        @local_types = mapper.local_types
        @locals = mapper.locals
        @arrays = mapper.arrays
        @class_locals = mapper.class_locals
        @local_array_elems = mapper.local_array_elems
        @block_params = mapper.block_params
        @class_params = mapper.class_params
        @inferred_params = mapper.inferred_params
        @typed_params = mapper.typed_params
        @typed_method_returns = mapper.typed_method_returns
        @instance_method_raw_returns = mapper.instance_method_raw_returns
        @const_raw_types = mapper.const_raw_types
        @typed_ivars = mapper.typed_ivars
      end
    end
  end
end
