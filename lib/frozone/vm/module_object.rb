require_relative 'core'
require_relative 'method'
require_relative 'object_object'

module Frozone
  module Vm
    class ModuleObject < ObjectObject
      # TODO - the Module class _can_ be subclassed in ruby - need to work out how to deal with that
      def initialize(name, namespace, class_object = Core::MODULE_CLASS)
        super(class_object)

        raise "class/module name must be a Symbol or nil" unless name.nil? || name.is_a?(Symbol)
        @name = name
        raise "class/module namespace must be a module" unless namespace.nil? or namespace.is_a?(ModuleObject)
        @namespace = namespace
        @methods = {}
        @constants = {}
        @current_visibility = :public
      end

      attr_accessor :current_visibility

      def name = @name

      def to_s = "module #{@name}"

      def prepends = @prepends || []
      def modules  = @modules  || []

      def prepend_module(mod)
        @prepends ||= []
        @prepends << mod
      end

      def add_module(mod)
        @modules ||= []
        @modules << mod
      end

      def set_method(name, method)
        raise "method must be an Method" unless method.is_a?(Method)
        # TODO thread safety
        @methods[name] = method
      end

      def get_method(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @methods[name]
      end
      
      def set_constant(name, value)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants[name] = value
      end

      def get_constant(name)
        raise "name must be a Symbol" unless name.is_a?(Symbol)

        @constants[name]
      end

      def self.lookup_constant(name, scopes)
        # 1. Lexical scopes - not they're in reverse order of priority
        scopes.reverse_each do |class_or_module|
          constant = class_or_module.get_constant(name)
          return constant unless constant.nil?
        end

        # 2. Class hierarchy look-up
        class_or_module = scopes.last
        if class_or_module.is_a?(ClassObject)
          constant = class_or_module.lookup_constant(name)
          return constant unless constant.nil?
        end

        # 3. No luck - Vm will try missing_const or else raise
        nil
      end
    end
  end
end
