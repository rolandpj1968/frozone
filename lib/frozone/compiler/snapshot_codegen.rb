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
        @inferred_params      = {}   # method_name (Symbol) => [Crystal type string, ...]
        @typed_locals         = {}   # local_name (Symbol) => :i64 | :f64 (per-method, reset each emit)
        @typed_params         = {}   # method_name => [:i64/:f64, ...] (specialized raw overload params)
        @typed_method_returns = {}   # method_name => :i64 | :f64 (return type of specialized overload)

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

        # Type inference pre-pass: infer param types from call sites in execute block
        infer_call_site_types(execute_block) if execute_block

        # Method specialisation pre-passes: raw-typed free-call sites → specialized overloads
        collect_raw_call_sites(execute_block) if execute_block
        collect_typed_method_returns

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
          @typed_locals = infer_local_types(execute_block.body)
          emit_indent
          emit(execute_block.body)
          emit_newline
          @typed_locals = {}
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

          if @typed_params[name] && @typed_method_returns[name]
            emit_indent
            emit_specialized_vm_method(name, method)
            emit_newline
            emit_newline
          end

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
        old_typed = @typed_locals
        @typed_locals = method.body ? infer_local_types(method.body) : {}
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
      ensure
        @typed_locals = old_typed
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

      # -----------------------------------------------------------------------
      # Unboxed local type inference and raw emission
      # -----------------------------------------------------------------------

      ARITH_OPS_UNBOX = %i[+ - * ** / %].to_set

      # Returns :i64, :f64, or nil for the provable bare Crystal type of a node.
      def node_raw_type(node)
        return nil unless node
        case node
        when Ast::IntegerLiteral then :i64
        when Ast::FloatLiteral   then :f64
        when Ast::LocalVariableRead
          @typed_locals[ivar(node, :name)]
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          # Free call to a typed-return method
          if recv.nil? && (ret_ty = @typed_method_returns[name])
            return ret_ty
          end
          # Arithmetic op on two raw-typed operands
          return nil unless ARITH_OPS_UNBOX.include?(name) && args.size == 1
          rt = node_raw_type(recv)
          at = node_raw_type(args[0])
          return nil unless rt && at
          (rt == :f64 || at == :f64) ? :f64 : :i64
        else nil
        end
      end

      # Infer which method-body locals can be emitted as bare Int64/Float64.
      #
      # Two-phase fixed-point:
      #   1. Seed from literal assignments (IntegerLiteral → :i64, FloatLiteral → :f64).
      #   2. Expand: promote any un-typed local whose ALL assignments are provably typed
      #      (handles propagation like `_iopw_i0 = j` when j is already typed).
      #   3. Narrow: evict any local whose assignments are not all consistent with its type.
      #   4. Repeat 2-3 until stable.
      def infer_local_types(body)
        return {} unless body
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)
        return {} if assignments.empty?

        old_typed = @typed_locals

        # Phase 1: seed from literals
        @typed_locals = {}
        assignments.each do |name, nodes|
          nodes.each do |n|
            case n
            when Ast::IntegerLiteral then @typed_locals[name] ||= :i64
            when Ast::FloatLiteral   then @typed_locals[name]  = :f64
            end
          end
        end

        # Phase 2+3: expand then narrow until fixpoint
        loop do
          prev = @typed_locals.dup

          # Expand: type any local whose assignments are all uniformly typed
          assignments.each do |name, nodes|
            next if @typed_locals[name]
            types = nodes.map { |n| node_raw_type(n) }
            next if types.any?(&:nil?)
            unique = types.uniq
            @typed_locals[name] = unique[0] if unique.size == 1
          end

          # Narrow: evict any local with an inconsistent assignment
          assignments.each do |name, nodes|
            next unless (ty = @typed_locals[name])
            ok = nodes.all? do |n|
              nt = node_raw_type(n)
              nt == ty || (ty == :f64 && nt == :i64)
            end
            @typed_locals.delete(name) unless ok
          end

          break if @typed_locals == prev
        end

        result = @typed_locals
        @typed_locals = old_typed
        result
      end

      # Walk a body AST collecting all LocalVariableWrite RHS nodes per name.
      # Does not descend into block bodies (block params share Ruby scope but
      # may receive heterogeneous types from the block caller).
      def collect_local_assignments(node, result)
        return unless node
        case node
        when Ast::LocalVariableWrite
          result[ivar(node, :name)] << ivar(node, :value_node)
          collect_local_assignments(ivar(node, :value_node), result)
        when Ast::Sequence
          node.nodes.each { |n| collect_local_assignments(n, result) }
        when Ast::If
          collect_local_assignments(ivar(node, :condition_node), result)
          collect_local_assignments(ivar(node, :then_node), result)
          collect_local_assignments(ivar(node, :else_node), result)
        when Ast::While, Ast::Until
          collect_local_assignments(ivar(node, :condition_node), result)
          collect_local_assignments(ivar(node, :body_node), result)
        when Ast::Return
          collect_local_assignments(ivar(node, :value_node), result)
        else
          %i[body_node value_node then_node else_node condition_node receiver_node].each do |slot|
            next unless node.instance_variable_defined?(:"@#{slot}")
            child = node.instance_variable_get(:"@#{slot}")
            collect_local_assignments(child, result) if child.is_a?(Ast::Node)
          end
          if node.instance_variable_defined?(:@arg_nodes)
            Array(node.instance_variable_get(:@arg_nodes)).each do |a|
              collect_local_assignments(a, result) if a.is_a?(Ast::Node)
            end
          end
        end
      end

      # Emit a node as a bare Crystal numeric (Int64 or Float64).
      # Only call when node_raw_type(node) is non-nil.
      def emit_raw(node)
        case node
        when Ast::IntegerLiteral
          write "#{ivar(node, :value).raw}_i64"
        when Ast::FloatLiteral
          val = ivar(node, :value)
          val = val.respond_to?(:raw) ? val.raw : val
          write "#{val}_f64"
        when Ast::LocalVariableRead
          write crystal_local(ivar(node, :name))
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          if recv.nil? && @typed_params[name]
            # Free call to typed-param method: pass raw args
            write crystal_method_name(name)
            write "("
            args.each_with_index do |a, i|
              write ", " if i > 0
              emit_raw(a)
            end
            write ")"
          elsif (ARITH_OPS_UNBOX | COMPARE_OPS).include?(name) && args.size == 1 && recv
            write "("
            emit_raw(recv)
            write " #{name} "
            emit_raw(args[0])
            write ")"
          else
            emit(node)
          end
        else
          emit(node)
        end
      end

      # Emit node coerced to Int64: raw if already typed, else .to_i64 on boxed.
      def emit_coerce_i64(node)
        node_raw_type(node) ? emit_raw(node) : (emit(node); write ".to_i64")
      end

      # Emit node coerced to Float64: raw if already typed, else .to_f64 on boxed.
      def emit_coerce_f64(node)
        node_raw_type(node) ? emit_raw(node) : (emit(node); write ".to_f64")
      end

      # Override: for typed locals in boxed context, wrap in RubyInteger/RubyFloat.
      def emit_local_var_read(node)
        case @typed_locals[ivar(node, :name)]
        when :i64 then write "RubyInteger.new(#{crystal_local(ivar(node, :name))})"
        when :f64 then write "RubyFloat.new(#{crystal_local(ivar(node, :name))})"
        else super
        end
      end

      # Override: for typed locals, emit RHS as bare Crystal numeric.
      def emit_local_var_write(node)
        name = ivar(node, :name)
        return super unless @typed_locals[name]
        write "#{crystal_local(name)} = "
        emit_raw(ivar(node, :value_node))
      end

      # Override: for index op-write (ci[j] += ...) with a raw-typed index,
      # emit the index temp as bare Int64 so the Int64 array overload is used.
      def emit_index_op_write(node)
        idx = ivar(node, :index_arg_nodes)&.first
        return super unless idx && node_raw_type(idx)
        op        = ivar(node, :operator)
        recv_node = ivar(node, :receiver_node)
        val_node  = ivar(node, :value_node)
        r = "_iopw_r#{@temp_counter}"
        i = "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        write "(#{r} = "
        recv_node ? emit(recv_node) : write("self")
        write "; #{i} = "
        emit_raw(idx)
        write "; #{r}[#{i}] = (#{r}[#{i}] #{op} "
        emit(val_node)
        write "))"
      end

      # Override: for [] with a raw-typed index, pass Int64 directly.
      # Also intercepts free calls to typed-param/return methods with all-raw args.
      def emit_method_call(node)
        if node.name == :[] && node.receiver_node && node.arg_nodes&.size == 1 &&
           node_raw_type(node.arg_nodes[0])
          emit(node.receiver_node)
          write "["
          emit_raw(node.arg_nodes[0])
          write "]"
          return
        end

        # Free call to a specialized method with all-raw args → use Int64 overload
        if node.receiver_node.nil? && @typed_method_returns[node.name] &&
           (tp = @typed_params[node.name])
          args = node.arg_nodes || []
          if args.size == tp.size && args.all? { |a| node_raw_type(a) }
            write crystal_method_name(node.name)
            write "("
            args.each_with_index do |a, i|
              write ", " if i > 0
              emit_raw(a)
            end
            write ")"
            return
          end
        end

        super
      end

      # Override: for []= with a raw-typed index, pass Int64 directly.
      def emit_attribute_write(node)
        if ivar(node, :name) == :[]= && node_raw_type(ivar(node, :arg_nodes)&.first)
          args = ivar(node, :arg_nodes)
          emit(ivar(node, :receiver_node))
          write "["
          emit_raw(args[0])
          write "] = "
          emit(args[1])
          return
        end
        super
      end

      # Override: for comparisons with at least one raw-typed operand, use bare
      # Crystal comparison with .to_i64/.to_f64 coercion on the untyped side.
      def emit_truthy(node)
        if comparison_op_call?(node)
          recv = node.receiver_node
          arg  = node.arg_nodes[0]
          rt   = node_raw_type(recv)
          at   = node_raw_type(arg)
          if rt || at
            ty = (rt == :f64 || at == :f64) ? :f64 : :i64
            write "("
            ty == :i64 ? emit_coerce_i64(recv) : emit_coerce_f64(recv)
            write " #{node.name} "
            ty == :i64 ? emit_coerce_i64(arg)  : emit_coerce_f64(arg)
            write ")"
            return
          end
        end
        super
      end

      # -----------------------------------------------------------------------
      # Method type specialisation — raw Int64/Float64 overloads
      # -----------------------------------------------------------------------

      # Walk the execute block looking for free calls where ALL args are raw-typed.
      # Populates @typed_params with {method_name => [:i64/:f64, ...]} for consistent sites.
      def collect_raw_call_sites(execute_block)
        return unless execute_block
        old_typed    = @typed_locals
        @typed_locals = infer_local_types(execute_block.body)
        raw_calls    = Hash.new { |h, k| h[k] = [] }
        walk_raw_free_calls(execute_block.body, raw_calls)
        @typed_locals = old_typed

        raw_calls.each do |name, call_type_lists|
          next if call_type_lists.empty?
          next unless call_type_lists.all? { |types| types.all? }      # all non-nil
          arities = call_type_lists.map(&:size).uniq
          next unless arities.size == 1                                  # consistent arity
          merged = call_type_lists.reduce { |a, b| a.zip(b).map { |ta, tb| ta == tb ? ta : nil } }
          @typed_params[name] = merged if merged&.all?
        end
      end

      def walk_raw_free_calls(node, raw_calls)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| walk_raw_free_calls(n, raw_calls) }
        when Ast::MethodCall
          recv = node.receiver_node
          name = node.name
          args = node.arg_nodes || []
          if recv.nil? && @user_methods.include?(name)
            raw_calls[name] << args.map { |a| node_raw_type(a) }
          end
          args.each { |a| walk_raw_free_calls(a, raw_calls) }
          blk = node.instance_variable_get(:@block_node)
          walk_raw_free_calls(blk.body, raw_calls) if blk&.respond_to?(:body) && blk.body
        when Ast::If
          walk_raw_free_calls(node.instance_variable_get(:@pred_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@then_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@else_node), raw_calls)
        when Ast::While, Ast::Until
          walk_raw_free_calls(node.instance_variable_get(:@condition_node), raw_calls)
          walk_raw_free_calls(node.instance_variable_get(:@body_node), raw_calls)
        else
          %i[body_node value_node then_node else_node condition_node].each do |slot|
            next unless node.instance_variable_defined?(:"@#{slot}")
            child = node.instance_variable_get(:"@#{slot}")
            walk_raw_free_calls(child, raw_calls) if child.is_a?(Ast::Node)
          end
          if node.instance_variable_defined?(:@arg_nodes)
            Array(node.instance_variable_get(:@arg_nodes)).each do |a|
              walk_raw_free_calls(a, raw_calls) if a.is_a?(Ast::Node)
            end
          end
        end
      end

      # For each method in @typed_params, tentatively assume same-type return,
      # then verify by walking the method body. Methods that fail verification
      # are removed from both @typed_params and @typed_method_returns.
      def collect_typed_method_returns
        return if @typed_params.empty?
        methods_table = @top_level_scope.instance_variable_get(:@methods_table) || {}

        # Tentative assignment (allows recursive calls to see a return type during verification)
        @typed_params.each do |name, param_types|
          @typed_method_returns[name] = param_types.first if param_types.uniq.size == 1
        end

        to_remove = []
        @typed_params.each do |name, param_types|
          method = methods_table[name]
          unless method.is_a?(Vm::Method) && method.body
            to_remove << name; next
          end
          # Only specialise methods with purely required params (no optionals/rest/kw)
          req = ivar(method, :required_params) || []
          unless req.size == param_types.size &&
                 ivar(method, :optional_params).to_a.empty? &&
                 ivar(method, :rest_param).nil?
            to_remove << name; next
          end

          old_typed     = @typed_locals
          @typed_locals = req.zip(param_types).to_h
          actual_return = infer_body_return_type(method.body)
          raw_safe      = body_all_raw_safe?(method.body)
          @typed_locals = old_typed

          unless actual_return == @typed_method_returns[name] && raw_safe
            to_remove << name
          end
        end

        to_remove.each { |n| @typed_params.delete(n); @typed_method_returns.delete(n) }
      end

      # Returns the raw Crystal type (:i64/:f64) of the last expression in a body,
      # or nil if it cannot be determined or is not a raw numeric type.
      def infer_body_return_type(body)
        return nil unless body
        case body
        when Ast::Sequence then infer_body_return_type(body.nodes.last)
        when Ast::If
          t = infer_body_return_type(ivar(body, :then_node))
          e = infer_body_return_type(ivar(body, :else_node))
          (t && t == e) ? t : nil
        when Ast::Return   then infer_body_return_type(ivar(body, :value_node))
        else               node_raw_type(body)
        end
      end

      # Returns true iff the entire body can be emitted in "raw mode" without
      # boxing — i.e., every sub-expression is either a raw literal/local, an
      # arithmetic/comparison op, or a call to another specialised method.
      def body_all_raw_safe?(node)
        return true unless node
        case node
        when Ast::IntegerLiteral, Ast::FloatLiteral, Ast::NilLiteral,
             Ast::TrueLiteral, Ast::FalseLiteral then true
        when Ast::LocalVariableRead  then true
        when Ast::LocalVariableWrite then body_all_raw_safe?(ivar(node, :value_node))
        when Ast::Sequence           then node.nodes.all? { |n| body_all_raw_safe?(n) }
        when Ast::Return             then body_all_raw_safe?(ivar(node, :value_node))
        when Ast::If
          body_all_raw_safe?(ivar(node, :pred_node)) &&
            body_all_raw_safe?(ivar(node, :then_node)) &&
            body_all_raw_safe?(ivar(node, :else_node))
        when Ast::MethodCall
          name = ivar(node, :name)
          recv = ivar(node, :receiver_node)
          args = ivar(node, :arg_nodes) || []
          if recv.nil?
            # Free call — must be to a specialised method
            @typed_method_returns.key?(name) ? args.all? { |a| body_all_raw_safe?(a) } : false
          elsif (ARITH_OPS_UNBOX | COMPARE_OPS).include?(name) && args.size == 1
            body_all_raw_safe?(recv) && body_all_raw_safe?(args[0])
          else
            false
          end
        else false
        end
      end

      # Emit a Crystal method with raw Int64/Float64 param and return types.
      # Only called when @typed_params[name] and @typed_method_returns[name] are set.
      def emit_specialized_vm_method(name, method)
        param_types = @typed_params[name]
        return_type = @typed_method_returns[name]
        req_params  = ivar(method, :required_params) || []
        return unless req_params.size == param_types.size

        cr = { i64: 'Int64', f64: 'Float64' }
        parts = req_params.zip(param_types).map { |p, ty| "#{crystal_local(p)} : #{cr[ty]}" }

        write "def #{crystal_method_name(name)}(#{parts.join(', ')}) : #{cr[return_type]}"
        emit_newline

        old_typed     = @typed_locals
        @typed_locals = req_params.zip(param_types).to_h
        indented { emit_raw_body(method.body) }
        @typed_locals = old_typed

        emit_newline
        emit_indent
        write "end"
      end

      # Emit a method body in raw (unboxed) mode: structural nodes are handled
      # normally (if/sequence/assignments), expressions are emitted via emit_raw.
      def emit_raw_body(node)
        return unless node
        case node
        when Ast::Sequence
          node.nodes.each { |n| emit_indent; emit_raw_body(n); emit_newline }
        when Ast::If
          write "if "
          cond = ivar(node, :pred_node)
          if cond.is_a?(Ast::MethodCall) && (ARITH_OPS_UNBOX | COMPARE_OPS).include?(ivar(cond, :name)) &&
             (ivar(cond, :arg_nodes) || []).size == 1
            emit_raw(ivar(cond, :receiver_node))
            write " #{ivar(cond, :name)} "
            emit_raw((ivar(cond, :arg_nodes))[0])
          else
            emit_raw(cond)
          end
          emit_newline
          indented { emit_raw_body(ivar(node, :then_node)) }
          else_node = ivar(node, :else_node)
          if else_node
            emit_indent; write "else"; emit_newline
            indented { emit_raw_body(else_node) }
          end
          emit_indent; write "end"
        when Ast::Return
          write "return "
          val = ivar(node, :value_node)
          emit_raw(val) if val
        when Ast::LocalVariableWrite
          write "#{crystal_local(ivar(node, :name))} = "
          emit_raw(ivar(node, :value_node))
        else
          emit_raw(node)
        end
      end

      # -----------------------------------------------------------------------
      # Soundness guard for comparison-operator simplification
      # -----------------------------------------------------------------------

      # Primitive classes whose comparison operators we trust to be unoverridden.
      PRIMITIVE_CLASS_NAMES = %i[Integer Float String].freeze

      # Override: only simplify comparisons when the operator has not been
      # overridden by user code on Integer, Float, or String.
      def comparison_op_call?(node)
        super && !user_overrides_comparison?(node.name)
      end

      def user_overrides_comparison?(op_name)
        @user_overridden_ops ||= begin
          ops = Set.new
          PRIMITIVE_CLASS_NAMES.each do |klass_name|
            klass = @top_level_scope.instance_variable_get(:@constants_table)&.fetch(klass_name, nil)
            next unless klass.is_a?(Vm::ModuleObject)
            klass.instance_variable_get(:@methods_table)&.each do |mname, method|
              next unless method.is_a?(Vm::Method)
              next unless user_source_location?(method.source_location)
              ops << mname if COMPARE_OPS.include?(mname)
            end
          end
          ops
        end
        @user_overridden_ops.include?(op_name)
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
