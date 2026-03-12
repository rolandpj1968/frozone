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
        elsif @name == :"$/" || @name == :"$-0"
          unless value.is_a?(Vm::StringObject) || value.is_a?(Vm::NilObject)
            type_name = vm_type_name(value)
            raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{type_name} into String")
          end
          Vm::GLOBALS[:"$/"] = value
        elsif @name == :"$@"
          set_dollar_at(value)
        elsif @name == :"$VERBOSE"
          coerced = if value.is_a?(Vm::NilObject) then Vm::NilObject::NIL
                    elsif !value.truthy? then Vm::FalseObject::FALSE
                    else Vm::TrueObject::TRUE
                    end
          Vm::GLOBALS[:"$VERBOSE"] = coerced
        elsif @name == :"$DEBUG" || @name == :"$-d"
          Vm::GLOBALS[:"$DEBUG"] = value.truthy? ? Vm::TrueObject::TRUE : Vm::FalseObject::FALSE
        else
          Vm::GLOBALS[@name] = value
        end
        value
      end

      private

      def vm_type_name(value)
        value.respond_to?(:class_object) && value.class_object ? value.class_object.name : value.class.name
      end

      def set_dollar_at(value)
        bang = Vm::GLOBALS.fetch(:"$!", Vm::NilObject::NIL)
        if bang.is_a?(Vm::NilObject)
          raise Vm::FrozoneException.make(:ArgumentError, "$! not set")
        end
        unless value.is_a?(Vm::NilObject) || value.is_a?(Vm::ArrayObject)
          raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{vm_type_name(value)} into Array")
        end
        Vm::GLOBALS[:"$@"] = value
      end

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
          last_non_nil = m.captures.reverse.find { |c| !c.nil? }
          Vm::GLOBALS[:"$+"] = last_non_nil ? Vm::StringObject.new(last_non_nil) : Vm::NilObject::NIL
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
