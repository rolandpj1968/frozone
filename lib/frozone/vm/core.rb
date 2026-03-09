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

      # Trivial singleton classes — simpler to define here than bootstrap from hierarchy.rb
      NIL_CLASS_CLASS   = ClassObject.new(:NilClass,   nil, OBJECT_CLASS)
      TRUE_CLASS_CLASS  = ClassObject.new(:TrueClass,  nil, OBJECT_CLASS)
      FALSE_CLASS_CLASS = ClassObject.new(:FalseClass, nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:NilClass,   NIL_CLASS_CLASS)
      OBJECT_CLASS.set_constant(:TrueClass,  TRUE_CLASS_CLASS)
      OBJECT_CLASS.set_constant(:FalseClass, FALSE_CLASS_CLASS)

      # Needed before any parsing happens (SymbolObject instances are created by the parser)
      SYMBOL_CLASS = ClassObject.new(:Symbol, nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:Symbol, SYMBOL_CLASS)

      # Defined here so VM objects can reference them as constants; hierarchy.rb adds module includes
      NUMERIC_CLASS = ClassObject.new(:Numeric,  nil, OBJECT_CLASS)
      INTEGER_CLASS = ClassObject.new(:Integer,  nil, NUMERIC_CLASS)
      FLOAT_CLASS   = ClassObject.new(:Float,    nil, NUMERIC_CLASS)
      STRING_CLASS  = ClassObject.new(:String,   nil, OBJECT_CLASS)
      ARRAY_CLASS   = ClassObject.new(:Array,    nil, OBJECT_CLASS)
      HASH_CLASS    = ClassObject.new(:Hash,     nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:Numeric,  NUMERIC_CLASS)
      OBJECT_CLASS.set_constant(:Integer,  INTEGER_CLASS)
      OBJECT_CLASS.set_constant(:Float,    FLOAT_CLASS)
      OBJECT_CLASS.set_constant(:String,   STRING_CLASS)
      OBJECT_CLASS.set_constant(:Array,    ARRAY_CLASS)
      OBJECT_CLASS.set_constant(:Hash,     HASH_CLASS)
    end
  end
end
