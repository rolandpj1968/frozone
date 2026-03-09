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
      # Essential constants so class/module lookups work in hierarchy.rb
      OBJECT_CLASS.set_constant(:BasicObject, BASIC_OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:Module, MODULE_CLASS)
      OBJECT_CLASS.set_constant(:Class, CLASS_CLASS)
      OBJECT_CLASS.set_constant(:Object, OBJECT_CLASS)

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
    end
  end
end
