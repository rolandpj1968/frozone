require_relative "../vm/core"
require_relative '../vm/module_object'
require_relative '../vm/nil_object'

module Frozone
  module Ast
    class ClassDef
      def initialize(name, locals, ast)
        raise "class name must be a Symbol" unless name.is_a?(Symbol)
        @name = name

        raise "class defn with locals not yet supported" unless locals.empty?
        @locals = locals

        @ast = ast
      end

      def to_s
        "class(#{@name}, locals: #{@locals} body: #{@ast})"
      end

      def evaluate(context)
        # 1. find or create the class defn and constant
        class_constant = Vm::ModuleObject.lookup_constant(@name, context.scopes)
        #puts "previous constant '#{@name}' #{class_constant}/#{class_constant.class}"
        unless class_constant.nil? or class_constant.is_a?(Vm::ClassObject)
          # TODO this is a real runtime error, not an assert
          raise "previous defn of #{@name} was not a class"
        end
        if class_constant.nil?
          # TODO namespace and superclass
          class_constant = Vm::ClassObject.new(@name, nil, nil)
          #puts "adding class '#{@name}' constant to scope #{context.scopes.last}"
          context.scopes.last.set_constant(@name, class_constant)
        end

        context.scopes << class_constant
        new_frame = Vm::Frame.new(context.frame.the_self, @locals, context.scopes)
        context.push_frame(new_frame)

        begin
          # $ ruby -e 'v = class C; 3; end; puts v'
          # 3
          @ast.evaluate(context)
        ensure
          context.pop_frame
          context.scopes.pop
        end
      end
    end
  end
end
