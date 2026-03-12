require_relative 'node'
require_relative '../vm/globals'
require_relative '../vm/frozone_exception'
require_relative '../vm/match_data_object'

module Frozone
  module Ast
    class GlobalVariableWrite < Node
      def initialize(name, value_node)
        @name = check_type("name", name, Symbol)
        @value_node = check_type("value_node", value_node, Node)
      end

      def to_s = "gvar(#{@name}) = #{@value_node}"

      def evaluate(context)
        value = @value_node.evaluate(context)
        store(context, value)
      end

      READ_ONLY = %i[$! $& $` $' $+ $1 $2 $3 $4 $5 $6 $7 $8 $9].freeze

      def store(context, value)
        if READ_ONLY.include?(@name)
          raise Vm::FrozoneException.make(:NameError, "#{@name} is a read-only variable")
        elsif @name == :"$~"
          set_match_global(value)
        else
          Vm::GLOBALS[@name] = value
        end
        value
      end

      private

      def set_match_global(value)
        if value.is_a?(Vm::NilObject)
          Vm::GLOBALS[:"$~"] = value
          Vm::GLOBALS.delete_if { |k, _| k.to_s =~ /^\$\d+$/ }
          Vm::GLOBALS[:"$&"] = Vm::GLOBALS[:"$`"] = Vm::GLOBALS[:"$'"] = Vm::NilObject::NIL
        elsif value.is_a?(Vm::MatchDataObject)
          m = value.raw
          Vm::GLOBALS[:"$~"] = value
          m.captures.each_with_index do |cap, i|
            Vm::GLOBALS[:"$#{i + 1}"] = cap ? Vm::StringObject.new(cap) : Vm::NilObject::NIL
          end
          Vm::GLOBALS[:"$&"] = Vm::StringObject.new(m[0])
          Vm::GLOBALS[:"$`"] = Vm::StringObject.new(m.pre_match)
          Vm::GLOBALS[:"$'"] = Vm::StringObject.new(m.post_match)
        else
          type_name = value.respond_to?(:class_object) && value.class_object ? value.class_object.name : value.class.name
          raise Vm::FrozoneException.make(:TypeError, "wrong argument type #{type_name} (expected MatchData)")
        end
      end
    end
  end
end
