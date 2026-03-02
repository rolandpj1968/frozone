module Frozone
  module Vm
    module Core
      def self.class_class = nil
    end
  end
end

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

      def self.class_class = CLASS_CLASS

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
      # TODO - parse these from source code

      KERNEL_MODULE = ModuleObject.new(:Kernel, nil)

      OBJECT_CLASS = ClassObject.new(:Object, nil, BASIC_OBJECT_CLASS)
      OBJECT_CLASS.add_module(KERNEL_MODULE)
      OBJECT_CLASS.set_constant(:BasicObject, BASIC_OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:Kernel, KERNEL_MODULE)
      OBJECT_CLASS.set_constant(:Object, OBJECT_CLASS)

      NIL_CLASS_CLASS = ClassObject.new(:NilClass, nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:NilClass, NIL_CLASS_CLASS)

      TRUE_CLASS_CLASS = ClassObject.new(:TrueClass, nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:TrueClass, TRUE_CLASS_CLASS)

      FALSE_CLASS_CLASS = ClassObject.new(:FalseClass, nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(:FalseClass, FALSE_CLASS_CLASS)

      COMPARABLE_MODULE = ModuleObject.new(:Comparable, nil)
      OBJECT_CLASS.set_constant(:Comparable, COMPARABLE_MODULE)

      STRING_CLASS = ClassObject.new(:String, nil, OBJECT_CLASS)
      STRING_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(:String, STRING_CLASS)

      SYMBOL_CLASS = ClassObject.new(:Symbol, nil, OBJECT_CLASS)
      SYMBOL_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(:Symbol, SYMBOL_CLASS)

      ENUMERABLE_MODULE = ModuleObject.new(:Enumerable, nil)
      OBJECT_CLASS.set_constant(:Enumerable, ENUMERABLE_MODULE)

      ARRAY_CLASS = ClassObject.new(:Array, nil, OBJECT_CLASS)
      ARRAY_CLASS.add_module(ENUMERABLE_MODULE)
      OBJECT_CLASS.set_constant(:Array, ARRAY_CLASS)

      HASH_CLASS = ClassObject.new(:Hash, nil, OBJECT_CLASS)
      HASH_CLASS.add_module(ENUMERABLE_MODULE)
      OBJECT_CLASS.set_constant(:Hash, HASH_CLASS)

      NUMERIC_CLASS = ClassObject.new(:Numeric, nil, OBJECT_CLASS)
      NUMERIC_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(:Symbol, SYMBOL_CLASS)

      INTEGER_CLASS = ClassObject.new(:Integer, nil, NUMERIC_CLASS)
      OBJECT_CLASS.set_constant(:Integer, INTEGER_CLASS)

      FLOAT_CLASS = ClassObject.new(:Float, nil, NUMERIC_CLASS)
      OBJECT_CLASS.set_constant(:Float, FLOAT_CLASS)
    end
  end
end
