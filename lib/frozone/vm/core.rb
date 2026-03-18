require_relative 'class_object'

module Frozone
  module Vm
    module Core
      BASIC_OBJECT_CLASS = ClassObject.new(:BasicObject, nil, nil)
      # empirically:
      #  $ ruby -e "puts BasicObject.constants"
      #  BasicObject
      BASIC_OBJECT_CLASS.set_constant(:BasicObject, BASIC_OBJECT_CLASS)

      MODULE_CLASS = ClassObject.new(:Module, nil, BASIC_OBJECT_CLASS)

      CLASS_CLASS = ClassObject.new(:Class, nil, MODULE_CLASS)

      BASIC_OBJECT_CLASS.patch_class_object
      MODULE_CLASS.patch_class_object
      CLASS_CLASS.patch_class_object
    end
  end
end

require_relative 'module_object'

module Frozone
  module Vm
    module Core
      OBJECT_CLASS = ClassObject.new(:Object, nil, BASIC_OBJECT_CLASS)
      # Fix bootstrap: Module and Class should inherit from Object, not BasicObject
      MODULE_CLASS.superclass = OBJECT_CLASS
      # CLASS_CLASS already has MODULE_CLASS as superclass (correct)
      # Essential constants so class/module lookups work in hierarchy.rb
      OBJECT_CLASS.set_constant(:BasicObject, BASIC_OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:Module, MODULE_CLASS)
      OBJECT_CLASS.set_constant(:Class, CLASS_CLASS)
      OBJECT_CLASS.set_constant(:Object, OBJECT_CLASS)

      def self.binding_class          = OBJECT_CLASS.get_constant(:Binding)
      def self.unbound_method_class  = OBJECT_CLASS.get_constant(:UnboundMethod)
      def self.method_class          = OBJECT_CLASS.get_constant(:Method)
      def self.io_class              = OBJECT_CLASS.get_constant(:IO)
      def self.process_status_class  = OBJECT_CLASS.get_constant(:Process).get_constant(:Status)
      def self.fiber_class           = OBJECT_CLASS.get_constant(:Fiber)

      def self.define_class(name, superclass)
        klass = ClassObject.new(name, nil, superclass)
        OBJECT_CLASS.set_constant(name, klass)
        klass
      end

      # Trivial singleton classes — simpler to define here than bootstrap from hierarchy.rb
      NIL_CLASS_CLASS   = define_class(:NilClass,   OBJECT_CLASS)
      TRUE_CLASS_CLASS  = define_class(:TrueClass,  OBJECT_CLASS)
      FALSE_CLASS_CLASS = define_class(:FalseClass, OBJECT_CLASS)

      # Needed before any parsing happens (SymbolObject instances are created by the parser)
      SYMBOL_CLASS = define_class(:Symbol, OBJECT_CLASS)

      # Defined here so VM objects can reference them as constants; hierarchy.rb adds module includes
      NUMERIC_CLASS = define_class(:Numeric, OBJECT_CLASS)
      INTEGER_CLASS = define_class(:Integer, NUMERIC_CLASS)
      FLOAT_CLASS   = define_class(:Float,   NUMERIC_CLASS)
      STRING_CLASS  = define_class(:String,  OBJECT_CLASS)
      ARRAY_CLASS   = define_class(:Array,   OBJECT_CLASS)
      HASH_CLASS    = define_class(:Hash,    OBJECT_CLASS)

      # Refinement is a subclass of Module (refinement objects are Module instances with extra methods)
      REFINEMENT_CLASS = define_class(:Refinement, MODULE_CLASS)
    end
  end
end
