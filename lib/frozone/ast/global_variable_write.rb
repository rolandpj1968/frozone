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
        # Follow alias to the canonical global name, check read-only on canonical
        if (canonical = Vm::GLOBAL_ALIASES[@name])
          if READ_ONLY.include?(canonical)
            raise Vm::FrozoneException.make(:NameError, "#{@name} is a read-only variable")
          end
          Vm::GLOBALS[canonical] = value
          return value
        end

        if READ_ONLY.include?(@name)
          raise Vm::FrozoneException.make(:NameError, "#{@name} is a read-only variable")
        elsif @name == :"$~"
          set_match_global(value)
        elsif @name == :"$="
          Vm::emit_warning(context, "variable $= is no longer effective; ignored")
          Vm::GLOBALS[:"$="] = value
        elsif @name == :"$/" || @name == :"$-0"
          unless value.is_a?(Vm::StringObject) || value.is_a?(Vm::NilObject) || string_subclass?(value)
            gname = @name == :"$/" ? "$/" : "$-0"
            raise Vm::FrozoneException.make(:TypeError, "value of #{gname} must be String")
          end
          gname = @name == :"$/" ? "'$/'".freeze : "'$-0'".freeze
          Vm::emit_warning(context, "#{gname} is deprecated") unless value.is_a?(Vm::NilObject)
          # For String subclass instances, create a plain frozen String copy
          value = coerce_to_string(context, value) if string_subclass?(value)
          Vm::GLOBALS[:"$/"] = value
          Vm::GLOBALS[:"$-0"] = value
        elsif @name == :"$\\" || @name == :"$," || @name == :"$;"
          unless value.is_a?(Vm::StringObject) || value.is_a?(Vm::NilObject) || string_subclass?(value)
            gname = @name == :"$\\" ? '$\\' : @name.to_s
            raise Vm::FrozoneException.make(:TypeError, "value of #{gname} must be String")
          end
          gname = "'#{@name}'"
          Vm::emit_warning(context, "#{gname} is deprecated") unless value.is_a?(Vm::NilObject)
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
          $0 = value.raw # also update the actual process name
        elsif @name == :"$DEBUG" || @name == :"$-d"
          Vm::GLOBALS[:"$DEBUG"] = value.truthy? ? Vm::TrueObject::TRUE : Vm::FalseObject::FALSE
        else
          Vm::GLOBALS[@name] = value
        end
        value
      end

      private

      def string_subclass?(value)
        # Returns true only for String subclass instances (not plain String instances)
        return false unless value.respond_to?(:class_object) && value.class_object
        return false if value.class_object.equal?(Vm::Core::STRING_CLASS)
        # Check if any ancestor is STRING_CLASS (i.e. it's a subclass)
        klass = value.class_object
        while klass
          return true if klass.equal?(Vm::Core::STRING_CLASS)
          klass = klass.respond_to?(:superclass) ? klass.superclass : nil
        end
        false
      end

      def coerce_to_string(context, value)
        raw_val = if value.respond_to?(:raw)
          value.raw
        else
          str = value.dispatch(context, :to_s, [], {})
          str.respond_to?(:raw) ? str.raw : str.to_s
        end
        s = Vm::StringObject.new(raw_val.to_s)
        s.freeze_object!
        s
      end

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
          # Validate each element is a String or Thread::Backtrace::Location (Ruby 3.4+)
          value.raw.each do |elem|
            unless elem.is_a?(Vm::StringObject) || backtrace_location?(elem)
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

      def backtrace_location?(elem)
        return false unless elem.is_a?(Vm::ObjectObject)
        klass = elem.class_object
        return false unless klass
        begin
          thread_class = Vm::Core::OBJECT_CLASS.get_constant(:Thread)
          return false unless thread_class
          bt_class = thread_class.get_constant(:Backtrace)
          return false unless bt_class
          loc_class = bt_class.get_constant(:Location)
          loc_class && klass.equal?(loc_class)
        rescue
          false
        end
      end

      def set_match_global(value)
        if value.is_a?(Vm::NilObject)
          Vm::GLOBALS[:"$~"] = value
          Vm::GLOBALS.delete_if { |k, _| k.to_s =~ /^\$[1-9]\d*$/ }
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
