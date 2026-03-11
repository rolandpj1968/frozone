require_relative '../utils'
require_relative '../ast/node'
require_relative 'frame'
require_relative 'array_object'
require_relative 'symbol_object'
require_relative 'proc_object'
require_relative 'frozone_exception'

module Frozone
  module Vm
    class Method
      include Utils

      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param, locals, body)
        @scopes = self.class.unique_scopes(check_array_type("scopes", scopes, ModuleObject))
        @name = check_type("name", name, Symbol)

        @required_params = check_array_type("required_params", required_params, Symbol)
        @optional_params = check_array_of_pairs_of_types("optional_params", optional_params, Symbol, Ast::Node)
        @rest_param = check_nil_or_type("rest_param", rest_param, Symbol)
        @post_params = check_array_type("post_params", post_params, Symbol)

        @required_kw_params = check_array_type("required_kw_params", required_kw_params, Symbol)
        @optional_kw_params = check_array_of_pairs_of_types("optional_kw_params", optional_kw_params, Symbol, Ast::Node)
        @kw_rest_param = check_nil_or_type("kw_rest_param", kw_rest_param, Symbol)

        @block_param = check_nil_or_type("block_param", block_param, Symbol)

        @locals = check_array_type("locals", locals, Symbol)
        @body = check_type("body", body, Ast::Node)
        @visibility = :public
      end

      attr_accessor :visibility

      def populate_params(context, new_frame, args)
        min_args_expected = @required_params.length + @post_params.length
        max_args_expected = @rest_param ? nil : (min_args_expected + @optional_params.length)

        if args.length < min_args_expected || (max_args_expected && max_args_expected < args.length)
          expecting = "#{min_args_expected}"
          if max_args_expected.nil?
            expecting += "+"
          elsif min_args_expected != max_args_expected
            expecting += "..#{max_args_expected}"
          end

          raise FrozoneException.make(:ArgumentError, "wrong number of arguments for #{@name} (given #{args.length} expecting #{expecting})")
        end

        @required_params.length.times do |i|
          new_frame.set_local(@required_params[i], args[i])
        end

        @post_params.length.times do |i|
          new_frame.set_local(@post_params[i], args[i - @post_params.length])
        end

        unless @optional_params.empty?
          n_args_left = args.length - min_args_expected
          @optional_params.length.times do |i|
            value =
              if i < n_args_left
                args[@required_params.length + i]
              else
                @optional_params[i][1].evaluate(context)
              end
            new_frame.set_local(@optional_params[i][0], value)
          end
        end

        unless @rest_param.nil?
          new_frame.set_local(@rest_param, ArrayObject.new(args[@required_params.length + @optional_params.length .. -@post_params.length - 1]))
        end
      end

      def populate_kw_params(context, new_frame, kw_args)
        @required_kw_params.each do |kw|
          raise FrozoneException.make(:ArgumentError, "missing keyword: #{kw}") unless kw_args.key?(kw)
          new_frame.set_local(kw, kw_args.delete(kw))
        end

        @optional_kw_params.each do |kw, value_node|
          value =
            if kw_args.key?(kw)
              kw_args.delete(kw)
            else
              value_node.evaluate(context)
            end
          new_frame.set_local(kw, value)
        end

        if @kw_rest_param.nil?
          unless kw_args.empty?
            raise FrozoneException.make(:ArgumentError, "unknown keyword#{kw_args.length == 1 ? "" : "s"}: #{kw_args.keys.map(&:to_s).join(', ')}")
          end
        else
          kw_rest = kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k }
          new_frame.set_local(@kw_rest_param, HashObject.new(kw_rest))
        end
      end

      def name = @name
      def scopes = @scopes

      def invoke(context, receiver, args, kw_args, block = nil)
        new_frame = Frame.new(receiver, @locals, @scopes)
        new_frame.block = block
        new_frame.method_frame = new_frame
        new_frame.current_method = self

        # If the method has no keyword params, convert kwargs to a positional Hash (Ruby semantics)
        if !kw_args.empty? && @required_kw_params.empty? && @optional_kw_params.empty? && @kw_rest_param.nil?
          hash_val = HashObject.new(kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k })
          args = args + [hash_val]
          kw_args = {}
        end

        new_frame.method_args = args
        new_frame.method_kwargs = kw_args

        populate_params(context, new_frame, args)
        populate_kw_params(context, new_frame, kw_args)

        if @block_param
          proc_obj = block ? ProcObject.new(block) : NilObject::NIL
          new_frame.set_local(@block_param, proc_obj)
        end

        context.push_frame(new_frame)
        begin
          @body.evaluate(context)
        rescue Ast::ReturnException => e
          raise e unless e.method_frame.equal?(new_frame)
          e.value
        rescue Ast::BreakException => e
          e.value
        ensure
          context.pop_frame
        end
      end

      # TODO
      def to_s = "method(#{@scopes.map(&:to_s)}, :#{@name}, #{@required_params} -> #{@body})"

      def alias_as(name)
        Method.new(@scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body)
      end

      # TODO - thread-safety
      # TODO - surely this does not belong here? There must be other uses of unique scopes?
      UniqueScopes = {}

      def self.unique_scopes(scopes)
        # TODO - thread safety
        UniqueScopes[scopes] ||= scopes.dup.freeze
      end
    end

    # A method created by define_method that delegates to a captured block
    class DefinedMethod
      attr_reader :name
      attr_accessor :visibility

      def initialize(name, block_obj)
        @name = name
        @block_obj = block_obj
        @visibility = :public
      end

      def invoke(context, receiver, args, kwargs, block: nil)
        @block_obj.invoke(context, args, receiver: receiver)
      end

      def alias_as(name) = DefinedMethod.new(name, @block_obj)
    end
  end
end
