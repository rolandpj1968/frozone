require_relative 'crystal_codegen'
require_relative '../vm/module_object'
require_relative '../vm/method'

module Frozone
  module Compiler
    # Snapshot-based Crystal code generator.
    #
    # Unlike CrystalCodegen (which is driven by a raw source AST), SnapshotCodegen
    # is driven by the *settled* Frozone VM state after the load phase has run:
    #
    #   1. Walk Core::OBJECT_CLASS to find user-defined top-level methods and classes.
    #   2. Serialise settled non-class constants (N=200, etc.) to Crystal initializers.
    #   3. Emit the execute-phase block body (from Frozone.compile! { ... }) as main.
    #
    # "User-defined" is determined by source_location: methods/constants whose
    # location does not fall inside lib/core/ or lib/frozone/ are user code.
    class SnapshotCodegen < CrystalCodegen
      # Path markers that identify Frozone-internal / core-library code.
      CORE_PATH_MARKERS = %w[lib/core/4.0/ lib/frozone/vm/ lib/frozone/ast/].freeze

      # Known VM-built constants on OBJECT_CLASS that should not be re-emitted.
      SKIP_CONSTANTS = %i[
        STDOUT STDERR STDIN ARGF
        RUBY_VERSION RUBY_PLATFORM RUBY_ENGINE RUBY_ENGINE_VERSION
        RUBY_RELEASE_DATE RUBY_REVISION RUBY_COPYRIGHT RUBY_DESCRIPTION
        RUBY_PATCHLEVEL RUBY_GEMS_LOCATIONS
        BasicObject Object Module Class Numeric Integer Float String Symbol
        Array Hash Proc Method UnboundMethod Range Regexp Encoding
        IO File Dir Signal Thread Fiber Mutex ConditionVariable Queue SizedQueue
        Exception StandardError RuntimeError ArgumentError TypeError NameError
        NoMethodError ZeroDivisionError IOError IndexError KeyError StopIteration
        NotImplementedError RangeError RegexpError SystemExit Interrupt
        SystemCallError EncodingError LoadError SyntaxError ScriptError
        Math Random GC ObjectSpace Comparable Enumerable Kernel
        RUBY_VERSION RUBY_PLATFORM RUBY_ENGINE
        NilClass TrueClass FalseClass Binding Struct Data Enumerator Complex Rational
        TOPLEVEL_BINDING ENV ARGV
      ].to_set

      # Generate Crystal source from the settled VM snapshot.
      #
      # @param execute_block [Ast::Block, nil]  the block passed to Frozone.compile!
      # @param top_level_scope [Vm::ClassObject] Core::OBJECT_CLASS
      # @param globals [Hash] Vm::GLOBALS
      def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
        @top_level_scope  = top_level_scope
        @stub_file        = stub_file
        @inferred_params  = {}   # method_name (Symbol) => [Crystal type string, ...]

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

        # Type inference pre-pass: infer param types from call sites in execute block
        infer_call_site_types(execute_block) if execute_block

        emit_header
        emit_bench_harness_require if bench_stub?
        emit_user_method_stubs unless @user_methods.empty?

        # User-defined classes and modules (from the constant table)
        emit_user_classes(top_level_scope)

        # User-defined top-level methods (private methods on Object defined in user code)
        emit_user_top_level_methods(top_level_scope)

        # Settled non-class constants
        emit_user_constants(top_level_scope)

        # Execute phase — the block body
        if execute_block
          emit_indent
          emit(execute_block.body)
          emit_newline
        end

        @out
      end

      private

      # -----------------------------------------------------------------------
      # Source-location filtering
      # -----------------------------------------------------------------------

      def user_source_location?(loc)
        return false if loc.nil?
        # source_location is "file:line" — strip the :line suffix for comparison
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @stub_file && file == @stub_file
        CORE_PATH_MARKERS.none? { |marker| file.include?(marker) }
      end

      def bench_stub?
        @stub_file&.include?('bench/stubs/')
      end

      def emit_bench_harness_require
        line %(require "./src/bench_harness")
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Pre-pass: collect user-defined method names for RubyObject stubs
      # -----------------------------------------------------------------------

      def collect_user_methods_from_scope(scope, visited = Set.new)
        return if visited.include?(scope.object_id)
        visited << scope.object_id

        # For user-defined classes, also include accessor methods (attr_accessor
        # etc.) whose source_location points to core but whose body is a simple
        # ivar read/write on this user-defined class.
        class_is_user = scope.instance_variable_get(:@constants_locations)&.any? do |_, loc|
          user_source_location?(loc)
        end || (scope != Vm::Core::OBJECT_CLASS &&
                scope.instance_variable_get(:@methods_table)&.any? do |_, m|
                  m.is_a?(Vm::Method) && user_source_location?(m.source_location)
                end)

        scope.instance_variable_get(:@methods_table)&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          if user_source_location?(method.source_location)
            @user_methods << name
          elsif class_is_user && accessor_method?(method)
            @user_methods << name
          end
        end

        scope.instance_variable_get(:@constants_table)&.each do |_name, value|
          next unless value.is_a?(Vm::ModuleObject)
          collect_user_methods_from_scope(value, visited)
        end
      end

      def collect_user_methods_from_block(block_node)
        return unless block_node
        collect_user_methods(block_node.body)
      end

      # -----------------------------------------------------------------------
      # Emit user-defined classes/modules
      # -----------------------------------------------------------------------

      def emit_user_classes(scope, visited = Set.new)
        return if visited.include?(scope.object_id)
        visited << scope.object_id

        scope.instance_variable_get(:@constants_table)&.each do |name, value|
          next unless value.is_a?(Vm::ModuleObject)
          next if SKIP_CONSTANTS.include?(name)
          emit_user_class(name, value)
          emit_user_classes(value, visited)
        end
      end

      def emit_user_class(name, mod)
        user_methods = mod.instance_variable_get(:@methods_table)&.select do |_n, m|
          m.is_a?(Vm::Method) &&
            (user_source_location?(m.source_location) || accessor_method?(m))
        end
        return if user_methods.nil? || user_methods.empty?
        # Must have at least one truly user-defined method (not just accessors)
        return unless user_methods.any? { |_, m| user_source_location?(m.source_location) }

        crystal_name = crystal_constant(name)
        is_class = mod.is_a?(Vm::ClassObject)
        kw = is_class ? "class" : "module"

        sc = is_class ? mod.instance_variable_get(:@superclass) : nil
        sc_name = sc&.instance_variable_get(:@name)

        write "#{kw} Ruby_#{crystal_name}"
        if sc_name && !%i[Object BasicObject].include?(sc_name)
          write " < Ruby_#{crystal_constant(sc_name)}"
        elsif is_class
          write " < RubyObject"
        end
        emit_newline

        indented do
          # Collect and emit ivar declarations (Crystal requires them upfront)
          all_ivars = []
          user_methods.each do |_mname, method|
            all_ivars |= collect_ivars(method.body) if method.body
          end
          all_ivars.each do |iv|
            emit_indent
            line "#{iv} : RubyObject = RUBY_NIL"
          end
          emit_newline unless all_ivars.empty?

          # Emit default to_s / inspect unless the user defined them
          unless user_methods.key?(:to_s)
            emit_indent
            line "def to_s : String; \"#<#{name}>\"; end"
          end
          unless user_methods.key?(:inspect)
            emit_indent
            line "def inspect : String; \"#<#{name}>\"; end"
          end

          user_methods.each do |mname, method|
            emit_indent
            if accessor_method?(method)
              emit_accessor_method(mname, method)
            else
              emit_vm_method(mname, method)
              emit_newline
              emit_newline
            end
          end
        end

        emit_indent
        write "end"
        emit_newline
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Emit user-defined top-level methods
      # -----------------------------------------------------------------------

      def emit_user_top_level_methods(scope)
        scope.instance_variable_get(:@methods_table)&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)
          emit_indent
          emit_vm_method(name, method, param_types: @inferred_params[name])
          emit_newline
          emit_newline
        end
      end

      # Emit a Crystal method definition from a Vm::Method object.
      # Vm::Method has the same ivar names as Ast::MethodDef, so we can pass
      # it directly to emit_param_list (which uses ivar/instance_variable_get).
      def emit_vm_method(name, method, param_types: nil)
        string_return = STRING_RETURN_METHODS.include?(name)
        crystal_name  = string_return ? name.to_s : crystal_method_name(name)

        write "def #{crystal_name}"
        write " : String" if string_return
        emit_param_list(method, param_types: param_types)
        emit_newline

        if string_return
          indented do
            write "(begin"
            emit_newline
            indented { emit(method.body) }
            emit_newline
            emit_indent
            write "end).to_s"
          end
        else
          indented { emit(method.body) }
        end

        emit_newline
        emit_indent
        write "end"
      end

      # -----------------------------------------------------------------------
      # Emit settled non-class constants
      # -----------------------------------------------------------------------

      def emit_user_constants(scope)
        const_table = scope.instance_variable_get(:@constants_table) || {}
        const_locs  = scope.instance_variable_get(:@constants_locations) || {}

        const_table.each do |name, value|
          next if SKIP_CONSTANTS.include?(name)
          next if value.is_a?(Vm::ModuleObject)

          loc = const_locs[name]
          next unless user_source_location?(loc)

          crystal_val = vm_value_to_crystal(value)
          next unless crystal_val

          line "Ruby_#{crystal_constant(name)} = #{crystal_val}"
        end
      end

      # Serialize a simple VM value to a Crystal expression string.
      # Returns nil for values that cannot be serialised (IO, Proc, etc.).
      def vm_value_to_crystal(value)
        case value
        when Vm::IntegerObject then "RubyInteger.new(#{value.raw}_i64)"
        when Vm::FloatObject   then "RubyFloat.new(#{value.raw}_f64)"
        when Vm::StringObject  then "RubyString.new(#{value.raw.inspect})"
        when Vm::NilObject     then "RUBY_NIL"
        when Vm::TrueObject    then "RUBY_TRUE"
        when Vm::FalseObject   then "RUBY_FALSE"
        when Vm::SymbolObject  then "RubySymbol.new(#{value.raw.inspect})"
        else                        nil
        end
      end

      # -----------------------------------------------------------------------
      # Type inference — call-site analysis from execute block
      # -----------------------------------------------------------------------

      # Infer Crystal type string for a Frozone AST expression node.
      # locals: Hash of Symbol => String (local name => Crystal type)
      def infer_expr_type(node, locals = {})
        return 'RubyObject' unless node
        case node
        when Ast::IntegerLiteral        then 'RubyInteger'
        when Ast::FloatLiteral          then 'RubyFloat'
        when Ast::StringLiteral, Ast::InterpolatedString then 'RubyString'
        when Ast::SymbolLiteral         then 'RubySymbol'
        when Ast::NilLiteral            then 'RubyNil'
        when Ast::TrueLiteral, Ast::FalseLiteral then 'RubyBool'
        when Ast::LocalVariableRead     then locals[ivar(node, :name)] || 'RubyObject'
        when Ast::MethodCall
          infer_call_return_type(node, locals)
        else
          'RubyObject'
        end
      end

      # Infer the return type of a method call node.
      NUMERIC_OPS = %i[+ - * **].to_set
      COMPARISON_OPS = %i[< <= > >= == !=].to_set

      def infer_call_return_type(node, locals)
        recv  = ivar(node, :receiver_node)
        name  = ivar(node, :name)
        args  = ivar(node, :arg_nodes) || []
        rt    = recv ? infer_expr_type(recv, locals) : nil
        at    = args.map { |a| infer_expr_type(a, locals) }

        if NUMERIC_OPS.include?(name)
          return 'RubyInteger' if (rt == 'RubyInteger' || rt.nil?) && at == ['RubyInteger']
          return 'RubyFloat'   if (rt == 'RubyFloat'   || rt.nil?) && at == ['RubyFloat']
          return 'RubyFloat'   if %w[RubyInteger RubyFloat].include?(rt) && at.all? { |t| %w[RubyInteger RubyFloat].include?(t) }
        end
        if COMPARISON_OPS.include?(name)
          return 'RubyBool' if rt && at.size == 1
        end
        'RubyObject'
      end

      # Walk the execute block body, collecting call-site argument types for
      # every free (non-method, non-receiver) call to user-defined methods.
      # Returns @inferred_params populated with param types.
      def infer_call_site_types(execute_block)
        walk_call_sites(execute_block.body, {})
      end

      def walk_call_sites(node, locals)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| walk_call_sites(n, locals) }
        when Ast::LocalVariableWrite
          type = infer_expr_type(ivar(node, :value_node), locals)
          locals = locals.merge(ivar(node, :name) => type)
          walk_call_sites(ivar(node, :value_node), locals)
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []

          # Only collect types for free (top-level) calls to user-defined methods
          if recv.nil? && @user_methods.include?(name)
            arg_types = args.map { |a| infer_expr_type(a, locals) }
            existing  = @inferred_params[name]
            @inferred_params[name] = if existing.nil?
              arg_types
            else
              # Join: if two call sites disagree on a position, fall back to RubyObject
              existing.zip(arg_types).map { |a, b| a == b ? a : 'RubyObject' }
            end
          end

          # Recurse into args and block
          args.each { |a| walk_call_sites(a, locals) }
          blk = ivar(node, :block_node)
          walk_call_sites(blk.body, locals) if blk&.respond_to?(:body) && blk.body
        when Ast::If
          walk_call_sites(ivar(node, :then_node), locals)
          walk_call_sites(ivar(node, :else_node), locals)
        when Ast::While
          walk_call_sites(ivar(node, :body), locals)
        else
          # Recurse into common child slots
          %i[body then_node else_node value_node].each do |slot|
            child = node.instance_variable_defined?(:"@#{slot}") && node.instance_variable_get(:"@#{slot}")
            walk_call_sites(child, locals) if child.is_a?(Ast::Node)
          end
        end
      end

      # Override emit_param_list to apply inferred types for required params.
      def emit_param_list(node, param_types: nil)
        return super(node) unless param_types

        parts  = []
        req    = ivar(node, :required_params) || []
        types  = param_types + ['RubyObject'] * [req.size - param_types.size, 0].max

        req.each_with_index do |p, i|
          parts << "#{crystal_local(p)} : #{types[i] || 'RubyObject'}"
        end

        ivar(node, :optional_params).each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        rp = ivar(node, :rest_param)
        parts << "*#{crystal_local(rp)} : RubyObject" if rp
        ivar(node, :post_params).each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        ivar(node, :required_kw_params).each { |p| parts << "#{p}: #{crystal_local(p)} : RubyObject" }
        ivar(node, :optional_kw_params).each { |p, default| parts << "#{p}: #{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        kr = ivar(node, :kw_rest_param)
        parts << "**#{crystal_local(kr)} : RubyObject" if kr
        bp = ivar(node, :block_param)
        parts << "&#{crystal_local(bp)}" if bp
        write "(#{parts.join(', ')})" unless parts.empty?
      end

      # Returns true if method is a simple ivar getter or setter (generated by
      # attr_accessor / attr_reader / attr_writer).  These have core source
      # locations but belong to user classes and must be emitted.
      def accessor_method?(method)
        body = method.body
        return false unless body
        case body
        when Ast::InstanceVariableRead  then true
        when Ast::InstanceVariableWrite then true
        else false
        end
      end

      # Emit an accessor method as an efficient one-liner.
      def emit_accessor_method(mname, method)
        body = method.body
        case body
        when Ast::InstanceVariableRead
          iv = ivar(body, :name)
          line "def #{crystal_method_name(mname)} : RubyObject; #{iv}; end"
        when Ast::InstanceVariableWrite
          iv   = ivar(body, :name)
          line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v; end"
        end
      end
    end
  end
end
