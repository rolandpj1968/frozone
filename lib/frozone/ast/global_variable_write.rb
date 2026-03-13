require_relative 'node'
require_relative '../vm/globals'
require_relative '../vm/frozone_exception'
require_relative '../vm/match_data_object'

module Frozone
  module Ast
    class GlobalVariableWrite < Node
      def initialize(name, value_node)
        @name = name
        @value_node = value_node
      end

      def to_s = "gvar(#{@name}) = #{@value_node}"

      def evaluate(context)
        value = @value_node.evaluate(context)
        store(context, value)
      end

      READ_ONLY = %i[$! $& $` $' $+ $1 $2 $3 $4 $5 $6 $7 $8 $9
                     $: $LOAD_PATH $-I $" $LOADED_FEATURES $< $FILENAME $? $-a $-l $-p].freeze

      def store(context, value)
        if READ_ONLY.include?(@name)
          raise Vm::FrozoneException.make(:NameError, "#{@name} is a read-only variable")
        elsif @name == :"$~"
          set_match_global(value)
        elsif @name == :"$/" || @name == :"$-0"
          unless value.is_a?(Vm::StringObject) || value.is_a?(Vm::NilObject)
            gname = @name == :"$/" ? "$/" : "$-0"
            raise Vm::FrozoneException.make(:TypeError, "value of #{gname} must be String")
          end
          Vm::GLOBALS[:"$/"] = value
          Vm::GLOBALS[:"$-0"] = value
        elsif @name == :"$\\" || @name == :"$,"
          unless value.is_a?(Vm::StringObject) || value.is_a?(Vm::NilObject)
            gname = @name == :"$\\" ? '$\\' : '$,'
            raise Vm::FrozoneException.make(:TypeError, "value of #{gname} must be String")
          end
          Vm::GLOBALS[@name] = value
        elsif @name == :"$."
          set_dollar_dot(context, value)
        elsif @name == :"$stdout" || @name == :"$>" || @name == :"$stderr" || @name == :"$stdin"
          set_io_global(context, @name, value)
        elsif @name == :"$@"
          set_dollar_at(context, value)
        elsif @name == :"$VERBOSE" || @name == :"$-v" || @name == :"$-w"
          coerced = if value.is_a?(Vm::NilObject) then Vm::NilObject::NIL
                    elsif !value.truthy? then Vm::FalseObject::FALSE
                    else Vm::TrueObject::TRUE
                    end
          Vm::GLOBALS[:"$VERBOSE"] = coerced
        elsif @name == :"$0" || @name == :"$PROGRAM_NAME"
          unless value.is_a?(Vm::StringObject)
            str = begin
              value.dispatch(context, :to_str, [], {})
            rescue
              nil
            end
            unless str.is_a?(Vm::StringObject)
              raise Vm::FrozoneException.make(:TypeError, "no implicit conversion of #{vm_type_name(value)} into String")
            end
            value = str
          end
          Vm::GLOBALS[:"$0"] = value
          Vm::GLOBALS[:"$PROGRAM_NAME"] = value
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

      def set_dollar_dot(context, value)
        int_val = if value.is_a?(Vm::IntegerObject)
                    value
                  elsif value.is_a?(Vm::FloatObject)
                    Vm::IntegerObject.new(value.raw.to_i)
                  else
                    # Try to_int
                    begin
                      result = value.dispatch(context, :to_int, [], {})
                      raise Vm::FrozoneException.make(:TypeError, "can't convert #{vm_type_name(value)} into Integer") unless result.is_a?(Vm::IntegerObject)
                      result
                    rescue Vm::FrozoneException => e
                      raise e
                    rescue
                      raise Vm::FrozoneException.make(:TypeError, "can't convert #{vm_type_name(value)} into Integer")
                    end
                  end
        Vm::GLOBALS[:"$."] = int_val
      end

      def set_io_global(context, name, value)
        unless value.is_a?(Vm::NilObject)
          has_write = begin
            value.dispatch(context, :respond_to?, [Vm::SymbolObject.from(:write)], {}).truthy?
          rescue
            !value.lookup_instance_method(:write).nil?
          end
          unless has_write
            type_name = vm_type_name(value)
            gname = name.to_s[1..]  # strip leading $
            raise Vm::FrozoneException.make(:TypeError, "$#{gname} must have write method, #{type_name} given")
          end
          Vm::GLOBALS[name] = value
          Vm::GLOBALS[:"$>"] = value if name == :"$stdout"
        else
          type_name = 'NilClass'
          gname = name.to_s[1..]
          raise Vm::FrozoneException.make(:TypeError, "$#{gname} must have write method, #{type_name} given")
        end
        value
      end

      def set_dollar_at(context, value)
        bang = Vm::GLOBALS.fetch(:"$!", Vm::NilObject::NIL)
        if bang.is_a?(Vm::NilObject)
          raise Vm::FrozoneException.make(:ArgumentError, "$! not set")
        end
        if value.is_a?(Vm::StringObject)
          # Single String: wrap in array
          arr = Vm::ArrayObject.new([value])
          Vm::GLOBALS[:"$@"] = arr
          bang.dispatch(context, :set_backtrace, [value], {})
        elsif value.is_a?(Vm::ArrayObject)
          # Validate each element is a String
          value.raw.each do |elem|
            unless elem.is_a?(Vm::StringObject)
              raise Vm::FrozoneException.make(:TypeError, "backtrace must be an Array of String")
            end
          end
          Vm::GLOBALS[:"$@"] = value
          bang.dispatch(context, :set_backtrace, [value], {})
        elsif value.is_a?(Vm::NilObject)
          Vm::GLOBALS[:"$@"] = value
          bang.dispatch(context, :set_backtrace, [value], {})
        else
          raise Vm::FrozoneException.make(:TypeError, "backtrace must be an Array of String")
        end
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
