require_relative '../utils'
require_relative 'module_object'
require_relative 'object_object'

module Frozone
  module Vm
    class ClassObject < ModuleObject
      include Utils

      def initialize(name, namespace, superclass)
        super(name, namespace, defined?(Core::CLASS_CLASS) ? Core::CLASS_CLASS : nil)
        @superclass = check_nil_or_type("superclass", superclass, ClassObject)
      end

      def superclass = @superclass

      def to_s = "class(#{@name})"

      # Called after CLASS_CLASS is defined to wire up the class pointer on bootstrap ClassObjects
      def patch_class_object
        @class_object = Core::CLASS_CLASS
        @eigenclass   = Core::CLASS_CLASS
      end

      # TODO &block
      def new_instance(context, args, kwargs)
        o = ObjectObject.new(self)
        o.dispatch(context, :initialize, args, kwargs, nil, private_ok: true)
        o
      end

      # TODO - private/public
      def lookup_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        # 1. Prepended modules
        unless @prepends.nil?
          @prepends.each do |mod|
            method = mod.get_method(name)
            return method unless method.nil?
          end
        end

        # 2. This class's methods
        method = get_method(name)
        return method unless method.nil?

        # 3. Module methods
        unless @modules.nil?
          @modules.each do |mod|
            method = mod.get_method(name)
            return method unless method.nil?
          end
        end

        # 4. Superclass
        unless @superclass.nil?
          method = @superclass.lookup_method(name)
          return method unless method.nil?
        end

        # 5.fail - missing_method and raise are done by the VM
        nil
      end

      # Class-hierarchy look-up
      # Note that full constant lookup starts with the lexical scopes in ModuleObject.lookup_constant.
      def lookup_constant(name)
        # 1. Prepended modules
        unless @prepends.nil?
          # TODO check forwards or reverse order here - I _think_ it's forwards which is counter-intuituve
          @prepends.each do |mod|
            constant = mod.get_constant(name)
            return constant unless constant.nil?
          end
        end

        # 2. This class's constants
        constant = get_constant(name)
        return constant unless constant.nil?

        # 3. Module constants
        unless @modules.nil?
          @modules.each do |mod|
            constant = mod.get_constant(name)
            return constant unless constant.nil?
          end
        end

        # 4. Superclass
        unless @superclass.nil?
          constant = @superclass.get_constant(name)
          return constant unless constant.nil?
        end

        # 5.fail - missing_constant and raise are done by the VM
        nil
      end
    end
  end
end
