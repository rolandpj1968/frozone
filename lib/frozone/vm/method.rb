require_relative '../utils'
require_relative '../ast/node'
require_relative 'frame'
require_relative 'array_object'
require_relative 'symbol_object'

module Frozone
  module Vm
    class Method
      include Utils

      # TODO - default params, keyword params, block param
      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, locals, body)
        @scopes = self.class.unique_scopes(check_array_type("scopes", scopes, ModuleObject))
        @name = check_type("name", name, Symbol)

        @required_params = check_array_type("required_params", required_params, Symbol)
        @optional_params = check_array_of_pairs_of_types("optional_params", optional_params, Symbol, Ast::Node)
        @rest_param = check_nil_or_type("rest_param", rest_param, Symbol)
        @post_params = check_array_type("post_params", post_params, Symbol)
        raise "post_params but no rest_param" if rest_param.nil? && post_params.any?

        @required_kw_params =
          check_array_type("required_kw_params", required_kw_params, Symbol).
            map { |s| SymbolObject.from(s) }
        @optional_kw_params =
          check_array_of_pairs_of_types("optional_kw_params", optional_kw_params, Symbol, Ast::Node)
            .map { |s, n| [SymbolObject.from(s), n] }

        @locals = check_array_type("locals", locals, Symbol)
        @body = check_type("body", body, Ast::Node)
      end

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

          # TODO - this is a runtime ArgumentError, not an intrinsic error
          raise "wrong number of arguments (given #{args.length} expecting #{expecting})"
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
          # TODO - this is a real runtime error
          raise "missing keyword: #{kw.raw.inspect}" unless kw_args.key?(kw)
          new_frame.set_local(kw.raw, kw_args.delete(kw))
        end

        @optional_kw_params.each do |kw, value_node|
          value = 
            if kw_args.key?(kw)
              kw_args.delete(kw)
            else
              value_node.evaluate(context)
            end
          new_frame.set_local(kw.raw, value)
        end
      end

      # TODO - default params, keyword params, block params
      def invoke(context, receiver, args, kw_args)
        new_frame = Frame.new(receiver, @locals, @scopes)

        populate_params(context, new_frame, args)

        populate_kw_params(context, new_frame, kw_args)

        context.push_frame(new_frame)
        begin
          @body.evaluate(context)
        ensure
          context.pop_frame
        end
      end

      # TODO
      def to_s = "method(#{@scopes.map(&:to_s)}, :#{@name}, #{@required_params} -> #{@body})"

      def alias_as(name)
        # TODO - default params, keyword params, block param - same same
        Method.new(@scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @locals, @body)
      end

      # TODO - thread-safety
      # TODO - surely this does not belong here? There must be other uses of unique scopes?
      UniqueScopes = {}

      def self.unique_scopes(scopes)
        # TODO - thread safety
        UniqueScopes[scopes] ||= scopes.dup.freeze
      end
    end
  end
end
