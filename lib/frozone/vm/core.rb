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
      BASIC_OBJECT_CLASS = ClassObject.new(SymbolObject.from(:BasicObject), nil, nil)
      # empirically:
      #  $ ruby -e "puts BasicObject.constants"
      #  BasicObject
      BASIC_OBJECT_CLASS.set_constant(SymbolObject.from(:BasicObject), BASIC_OBJECT_CLASS)

      MODULE_CLASS = ClassObject.new(SymbolObject.from(:Module), nil, BASIC_OBJECT_CLASS)

      CLASS_CLASS = ClassObject.new(SymbolObject.from(:Class), nil, MODULE_CLASS)

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

      KERNEL_MODULE = ModuleObject.new(SymbolObject.from(:Kernel), nil)

      OBJECT_CLASS = ClassObject.new(SymbolObject.from(:Object), nil, BASIC_OBJECT_CLASS)
      OBJECT_CLASS.add_module(KERNEL_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:BasicObject), BASIC_OBJECT_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Kernel), KERNEL_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Object), OBJECT_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Module), MODULE_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Class), CLASS_CLASS)

      NIL_CLASS_CLASS = ClassObject.new(SymbolObject.from(:NilClass), nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:NilClass), NIL_CLASS_CLASS)

      TRUE_CLASS_CLASS = ClassObject.new(SymbolObject.from(:TrueClass), nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:TrueClass), TRUE_CLASS_CLASS)

      FALSE_CLASS_CLASS = ClassObject.new(SymbolObject.from(:FalseClass), nil, OBJECT_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:FalseClass), FALSE_CLASS_CLASS)

      COMPARABLE_MODULE = ModuleObject.new(SymbolObject.from(:Comparable), nil)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Comparable), COMPARABLE_MODULE)

      STRING_CLASS = ClassObject.new(SymbolObject.from(:String), nil, OBJECT_CLASS)
      STRING_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:String), STRING_CLASS)

      SYMBOL_CLASS = ClassObject.new(SymbolObject.from(:Symbol), nil, OBJECT_CLASS)
      SYMBOL_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Symbol), SYMBOL_CLASS)

      # Patch all SymbolObjects created during bootstrap with the now-available SYMBOL_CLASS.
      SymbolObject.bootstrap!(SYMBOL_CLASS)

      ENUMERABLE_MODULE = ModuleObject.new(SymbolObject.from(:Enumerable), nil)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Enumerable), ENUMERABLE_MODULE)

      ARRAY_CLASS = ClassObject.new(SymbolObject.from(:Array), nil, OBJECT_CLASS)
      ARRAY_CLASS.add_module(ENUMERABLE_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Array), ARRAY_CLASS)

      HASH_CLASS = ClassObject.new(SymbolObject.from(:Hash), nil, OBJECT_CLASS)
      HASH_CLASS.add_module(ENUMERABLE_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Hash), HASH_CLASS)

      NUMERIC_CLASS = ClassObject.new(SymbolObject.from(:Numeric), nil, OBJECT_CLASS)
      NUMERIC_CLASS.add_module(COMPARABLE_MODULE)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Numeric), NUMERIC_CLASS)

      INTEGER_CLASS = ClassObject.new(SymbolObject.from(:Integer), nil, NUMERIC_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Integer), INTEGER_CLASS)

      FLOAT_CLASS = ClassObject.new(SymbolObject.from(:Float), nil, NUMERIC_CLASS)
      OBJECT_CLASS.set_constant(SymbolObject.from(:Float), FLOAT_CLASS)
    end
  end
end
