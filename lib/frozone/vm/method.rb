require_relative '../ast/node'
require_relative 'frame'
require_relative 'array_object'
require_relative 'symbol_object'
require_relative 'proc_object'
require_relative 'frozone_exception'

module Frozone
  module Vm
    class Method
      attr_reader :name, :scopes
      attr_reader :required_params, :optional_params, :rest_param, :post_params
      attr_reader :required_kw_params, :optional_kw_params, :kw_rest_param, :block_param
      attr_accessor :visibility, :nested_def_scope, :original_owner
      attr_accessor :active_refinements  # refinements active at method definition site
      attr_accessor :refining_module     # if set, collect all refinements from this module at invoke time

      attr_reader :uses_block, :source_location, :body, :locals

      # ruby2_keywords flag is stored in a shared holder array so aliases
      # of the same method see the same flag value (like MRI's shared definition).
      def ruby2_keywords = @ruby2_keywords_holder[0]

      def ruby2_keywords=(val)
        @ruby2_keywords_holder[0] = val
      end

      def initialize(scopes, name, required_params, optional_params, rest_param, post_params, required_kw_params, optional_kw_params, kw_rest_param, block_param, locals, body, uses_block: nil, source_location: nil)
        @scopes = self.class.unique_scopes(scopes)
        @name = name

        @required_params = required_params
        @optional_params = optional_params
        @rest_param = rest_param
        @post_params = post_params

        @required_kw_params = required_kw_params
        @optional_kw_params = optional_kw_params
        @kw_rest_param = kw_rest_param

        @block_param = block_param

        @locals = locals
        @body = body
        @visibility = :public
        @uses_block = uses_block
        @source_location = source_location
        @ruby2_keywords_holder = [false]
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

          raise FrozoneException.make(:ArgumentError, "wrong number of arguments (given #{args.length}, expected #{expecting})")
        end

        @required_params.length.times do |i|
          assign_param(context, new_frame, @required_params[i], args[i])
        end

        @post_params.length.times do |i|
          assign_param(context, new_frame, @post_params[i], args[i - @post_params.length])
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
          new_frame.set_local(@rest_param, ArrayObject.new(args[@required_params.length + @optional_params.length..-@post_params.length - 1] || []))
        end
      end

      def populate_kw_params(context, new_frame, kw_args)
        missing = @required_kw_params.reject { |kw| kw_args.key?(kw) }
        unless missing.empty?
          label = missing.length == 1 ? "keyword" : "keywords"
          raise FrozoneException.make(:ArgumentError, "missing #{label}: #{missing.map { |k| ":#{k}" }.join(', ')}")
        end
        @required_kw_params.each do |kw|
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

        if @kw_rest_param.nil? || @kw_rest_param == :__no_kwargs__
          unless kw_args.empty?
            raise FrozoneException.make(:ArgumentError, "unknown keyword#{kw_args.length == 1 ? "" : "s"}: #{kw_args.keys.map { |k| k.is_a?(Symbol) ? ":#{k}" : k.to_s }.join(', ')}")
          end
        else
          kw_rest = kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k }
          new_frame.set_local(@kw_rest_param, HashObject.new(kw_rest))
        end
      end

      private

      def assign_param(context, frame, param, val)
        if param.is_a?(Hash)
          sub_args = coerce_to_array(context, val)
          sub_names  = param[:names]
          sub_rest   = param[:rest]
          sub_rights = param[:rights] || []
          sub_names.each_with_index  { |n, j| assign_param(context, frame, n, sub_args.fetch(j, NilObject::NIL)) }
          if sub_rest
            rest_end  = sub_rights.length > 0 ? -(sub_rights.length + 1) : -1
            rest_vals = sub_args[sub_names.length..rest_end] || []
            frame.set_local(sub_rest, ArrayObject.new(rest_vals))
          end
          rights_start = [sub_args.length - sub_rights.length, sub_names.length].max
          sub_rights.each_with_index { |n, j| assign_param(context, frame, n, sub_args.fetch(rights_start + j, NilObject::NIL)) }
        else
          frame.set_local(param, val)
        end
      end

      def coerce_to_array(context, val)
        return val.raw if val.is_a?(ArrayObject)
        return [val] if val.is_a?(NilObject)
        has_to_ary = begin
          result = val.dispatch(context, :respond_to?, [SymbolObject.from(:to_ary), TrueObject::TRUE], {})
          result.truthy?
        rescue
          val.lookup_instance_method(:to_ary) ? true : false
        end
        if has_to_ary
          converted = val.dispatch(context, :to_ary, [], {})
          return converted.raw if converted.is_a?(ArrayObject)
          return [val] if converted.is_a?(NilObject)
          raise FrozoneException.make(:TypeError, "no implicit conversion of #{val.class_object.name} into Array")
        end
        [val]
      end

      public

      def invoke(context, receiver, args, kw_args, block = nil, from_super: false)
        # Warn about unused block (Ruby 3.4 strict_unused_block category)
        # initialize is exempt — blocks passed to .new are silently forwarded
        if !from_super && @name != :initialize && block && !block.is_a?(NilObject) && @uses_block == false && !@block_warning_emitted
          verbose = GLOBALS.fetch(:"$VERBOSE", FalseObject::FALSE).truthy?
          warning_class = Core::OBJECT_CLASS.get_constant(:Warning)
          strict = warning_class&.dispatch(context, :[], [SymbolObject.from(:strict_unused_block)], {})&.truthy? rescue false
          if verbose || strict
            @block_warning_emitted = true
            def_loc = @source_location || begin
              def_scope = @scopes.last
              def_scope.is_a?(ModuleObject) ? def_scope.name.to_s : def_scope.to_s
            end
            Frozone::Vm.emit_warning(context, "the block passed to '#{@name}' defined at #{def_loc} may be ignored", location: context.call_site)
          end
        end

        new_frame = Frame.new(receiver, @locals, @scopes, context.frame)
        new_frame.block = block
        new_frame.method_frame = new_frame
        new_frame.current_method = self
        new_frame.incoming_call_site = context&.call_site
        # def inside a method body goes to the method's defining scope, not the call-site scope
        new_frame.def_scope = @nested_def_scope || @scopes.last
        # Refinements active at definition site are active during invocation.
        # If refining_module is set, dynamically collect ALL current refinements from that module
        # (enables cross-refinement calls within the same refinement module).
        if @refining_module
          new_frame.active_refinements = collect_refining_module_refs(@refining_module)
        elsif @active_refinements
          new_frame.active_refinements = @active_refinements
        end

        # **nil parameter: reject any keyword arguments
        if @kw_rest_param == :__no_kwargs__ && !kw_args.empty?
          raise FrozoneException.make(:ArgumentError, "no keywords accepted")
        end

        # If the method has no keyword params, convert kwargs to a positional Hash (Ruby semantics)
        if !kw_args.empty? && @required_kw_params.empty? && @optional_kw_params.empty? && @kw_rest_param.nil?
          hash_val = HashObject.new(kw_args.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k })
          # ruby2_keywords method: mark the hash so it can be re-spread as kwargs at the call site
          hash_val.ruby2_keywords = true if ruby2_keywords
          args = args + [hash_val]
          kw_args = {}
        end

        new_frame.method_args = args
        new_frame.method_kwargs = kw_args

        # Push frame BEFORE populating params so default expressions can reference
        # earlier parameters (e.g. def foo(a, b = a.length)).
        context.push_frame(new_frame)
        begin
          populate_params(context, new_frame, args)
          populate_kw_params(context, new_frame, kw_args)

          if @block_param
            proc_obj = if block.is_a?(ProcObject)
                         block  # already a ProcObject — don't double-wrap
                       elsif block.is_a?(BoundMethodObject)
                         ProcObject.new(block, lambda: true)
                       elsif block.is_a?(NativeBlock) && block.is_lambda
                         ProcObject.new(block, lambda: true)
                       elsif block && !block.is_a?(NilObject)
                         ProcObject.new(block)
                       else
                         NilObject::NIL
                       end
            new_frame.set_local(@block_param, proc_obj)
          end

          @body.evaluate(context)
        rescue Ast::ReturnException => e
          if e.method_frame.nil? || !e.method_frame.alive?
            # No enclosing method context, or the defining scope has already exited:
            # proc/block return escaping its defining scope
            exc = FrozoneException.make(:LocalJumpError, "unexpected return")
            exc.vm_object.set_ivar(:@exit_value, e.value)
            exc.vm_object.set_ivar(:@reason, SymbolObject.from(:return))
            raise exc
          end
          raise e unless e.method_frame.equal?(new_frame)
          e.value
        rescue Ast::BreakException => e
          # Convert to LocalJumpError if break targets this frame (captured block called within
          # its defining scope) or if the defining frame is already dead (scope has returned).
          if e.method_frame.equal?(new_frame) || (e.method_frame && !e.method_frame.alive?)
            exc2 = FrozoneException.make(:LocalJumpError, "break from proc-closure")
            exc2.vm_object.set_ivar(:@exit_value, e.value)
            exc2.vm_object.set_ivar(:@reason, SymbolObject.from(:break))
            raise exc2
          end
          raise
        ensure
          new_frame.kill!
          context.pop_frame
        end
      end

      # TODO
      def to_s = "method(#{@scopes.map(&:to_s)}, :#{@name}, #{@required_params} -> #{@body})"

      def alias_as(name)
        m = Method.new(@scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
        m.original_owner = @original_owner
        m.visibility = @visibility
        m.active_refinements = @active_refinements
        m.refining_module = @refining_module
        m.instance_variable_set(:@ruby2_keywords_holder, @ruby2_keywords_holder)
        m
      end

      def dup_with_visibility(vis, original_owner: nil)
        m = Method.new(@scopes, @name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
        m.visibility = vis
        m.original_owner = original_owner || @original_owner
        m.active_refinements = @active_refinements
        m.refining_module = @refining_module
        m
      end

      def bound_copy(name, new_scope)
        m = Method.new([new_scope], name, @required_params, @optional_params, @rest_param, @post_params, @required_kw_params, @optional_kw_params, @kw_rest_param, @block_param, @locals, @body, uses_block: @uses_block, source_location: @source_location)
        m.active_refinements = @active_refinements
        m.refining_module = @refining_module
        m
      end

      private

      # Collect all refinements from a refining module at call time (for cross-refinement support).
      # The module's @__refinements__ is a Frozone HashObject with IntegerObject keys.
      def collect_refining_module_refs(mod)
        refinements = {}
        refs_obj = mod.get_ivar(:@__refinements__)
        unless refs_obj.is_a?(NilObject) || !refs_obj.is_a?(HashObject)
          refs_obj.raw.each do |k, v|
            key = k.is_a?(IntegerObject) ? k.raw : k
            refinements[key] = v if v.is_a?(ModuleObject)
          end
        end
        # Also collect from included ancestor modules
        mod.ancestors_list.each do |ancestor|
          next if ancestor.equal?(mod)
          next unless ancestor.is_a?(ModuleObject) && !ancestor.is_a?(ClassObject)
          anc_refs_obj = ancestor.get_ivar(:@__refinements__)
          next if anc_refs_obj.is_a?(NilObject) || !anc_refs_obj.is_a?(HashObject)
          anc_refs_obj.raw.each do |k, v|
            key = k.is_a?(IntegerObject) ? k.raw : k
            refinements[key] ||= v if v.is_a?(ModuleObject)  # ancestors don't override own
          end
        end
        refinements
      end

      public

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
      attr_reader :name, :scopes, :block_obj
      attr_accessor :visibility, :ruby2_keywords

      def initialize(name, block_obj, defining_class = nil)
        @name = name
        @block_obj = block_obj
        @visibility = :public
        @scopes = defining_class ? [defining_class] : []
      end

      def invoke(context, receiver, args, kwargs, block = nil, from_super: false)
        if ruby2_keywords && !kwargs.empty?
          hash_val = HashObject.new(kwargs.transform_keys { |k| k.is_a?(Symbol) ? SymbolObject.from(k) : k })
          hash_val.ruby2_keywords = true
          args = args + [hash_val]
          kwargs = {}
        end
        # Use the block's def_scope (from its definition context) so that `def` inside
        # a define_method block defines in the correct class (not the call-site class).
        block_def_scope = @block_obj.respond_to?(:enclosing_frame) ? @block_obj.enclosing_frame&.def_scope : nil
        @block_obj.invoke(context, args, kw_args: kwargs, receiver: receiver, block: block, current_method: self, as_method: true, def_scope: block_def_scope)
      rescue Ast::ReturnException => e
        # Absorb return from a proc used as a method body (define_method semantics).
        # Return with nil or dead method_frame exits the define_method-defined method.
        raise unless e.method_frame.nil? || !e.method_frame.alive?
        e.value
      end

      def alias_as(name) = DefinedMethod.new(name, @block_obj, @scopes.first)

      def dup_with_visibility(vis)
        m = DefinedMethod.new(@name, @block_obj, @scopes.first)
        m.visibility = vis
        m
      end
    end
  end
end
