require_relative 'crystal_codegen'
require_relative '../vm/module_object'
require_relative '../vm/method'
require_relative 'snapshot_codegen/raw_emission'
require_relative 'snapshot_codegen/array_analysis'
require_relative 'snapshot_codegen/ivar_analysis'
require_relative 'snapshot_codegen/method_specialisation'

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
      include SnapshotCodegenSupport::ArrayAnalysis
      include SnapshotCodegenSupport::RawEmission
      include SnapshotCodegenSupport::IvarAnalysis
      include SnapshotCodegenSupport::MethodSpecialisation

      # -----------------------------------------------------------------------
      # Optimization flags — per-optimization control (like gcc -fno-X)
      # -----------------------------------------------------------------------

      OPT_FLAGS = %i[
        unbox_locals          # Int64/Float64 local specialization
        call_site_types       # Inferred param types from call sites
        method_specialization # Raw Int64/Float64 method overloads
        typed_ivars           # Scalar-typed instance variables
        ivar_narrowing        # Class-typed ivar narrowing (X | nil)
        native_arrays         # Array(T) promotion for 1D arrays
        native_2d_arrays      # Array(Array(T)) promotion for 2D arrays
        tuple_literals        # RubyTupleN for small fixed-size arrays
        native_iteration      # Crystal .times/.upto/.downto
        raw_returns           # Typed-return raw body emission
        accessor_inline       # _raw accessor usage for self-calls
        devirtualize          # .as(Ruby_X) casts for class-typed receivers
        condition_simplify    # Bare Crystal Bool for comparisons
      ].freeze

      # -O0: all off. -O1: safe optimizations. -O2: all on (default).
      OPT_LEVELS = {
        0 => [],
        1 => %i[call_site_types tuple_literals devirtualize condition_simplify
                native_iteration accessor_inline],
        2 => OPT_FLAGS.dup
      }.freeze

      def initialize(opt_level: nil, **kw)
        super(**kw)
        level = opt_level || ENV.fetch('FROZONE_OPT_LEVEL', '2').to_i
        enabled = OPT_LEVELS.fetch(level, OPT_FLAGS).to_set
        # Per-flag env var overrides: FROZONE_NO_UNBOX_LOCALS=1
        OPT_FLAGS.each do |flag|
          env_key = "FROZONE_NO_#{flag.upcase}"
          enabled.delete(flag) if ENV[env_key]
        end
        @opt_flags = enabled
      end

      def opt?(flag) = @opt_flags.include?(flag)

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
        @inferred_params             = {}   # method_name (Symbol) => [Crystal type string, ...]
        @typed_locals                = {}   # local_name (Symbol) => :i64 | :f64 (per-method, reset each emit)
        @typed_params                = {}   # method_name => [:i64/:f64, ...] (specialized raw overload params)
        @typed_method_returns        = {}   # method_name => :i64 | :f64 (top-level method return type)
        @instance_method_raw_returns = {}   # [class_sym, method_sym] => :i64 | :f64
        @const_raw_types             = {}   # constant Symbol name => :i64 | :f64
        @typed_ivars                 = {}   # class Symbol name => {ivar_sym => :i64 | :f64}
        @class_typed_ivars           = {}   # class Symbol name => {ivar_sym => [:class, :Node] | [:class_or_nil, :Node]}
        @current_class_ivars         = {}   # active ivar type map during class method emission
        @current_class_typed_ivars   = {}   # active class-typed ivar map during class emission
        @current_class_name          = nil  # Symbol of class being emitted (nil at top level)
        @typed_array_locals          = {}   # local_name (Symbol) => :i64 | :f64 (element type; per-method)
        @ti_locals                   = {}   # mkey => {local_name => :i64 | :f64}
        @ti_arrays                   = {}   # mkey => {local_name => :i64 | :f64}
        @ti_class_locals             = {}   # mkey => {local_name => class_sym} (user-class-typed locals)
        @ti_local_array_elems        = {}   # mkey => {local_name => :i64 | :f64} (boxed RubyArray elem type)
        @ti_block_params             = {}   # mkey => {param_name => :i64 | :f64} (for-loop & array-block params)
        @ti_class_params             = {}   # [cname, mname] => [Crystal type string, ...]
        @current_class_locals        = {}   # active class-typed local map during method emission
        @current_local_array_elems   = {}   # active boxed-array elem type map during method emission
        @current_block_params        = {}   # active block-param type map (from TI :block_param slots)
        @raw_block_params            = {}   # param_name => :i64 | :f64 for currently-native block params
        @current_local_2d_arrays     = {}   # local_name => :i64 | :f64 — outer of Array(Array(T)) locals
        @native_array_locals         = {}   # local_name => :i64 | :f64 — Array(T) from 2D parent read

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

        # Whole-program type inference (replaces all ad-hoc pre-passes)
        run_type_inference(execute_block, top_level_scope)

        emit_header
        emit_bench_harness_require if bench_stub?
        emit_user_method_stubs unless @user_methods.empty?

        # Collect class-typed ivars (X | nil patterns) across all methods
        collect_class_typed_ivars(top_level_scope) if opt?(:ivar_narrowing)

        # User-defined classes and modules (from the constant table)
        emit_user_classes(top_level_scope)

        # User-defined top-level methods (private methods on Object defined in user code)
        emit_user_top_level_methods(top_level_scope)

        # Settled non-class constants
        emit_user_constants(top_level_scope)

        # Execute phase — the block body
        if execute_block
          @typed_locals               = opt?(:unbox_locals) ? (@ti_locals[nil] || {}) : {}
          @typed_array_locals         = opt?(:native_arrays) ? (@ti_arrays[nil] || {}) : {}
          @current_class_locals       = opt?(:devirtualize) ? (@ti_class_locals[nil] || {}) : {}
          @current_local_array_elems  = opt?(:native_arrays) ? (@ti_local_array_elems[nil] || {}) : {}
          @current_block_params       = @ti_block_params[nil]      || {}
          @current_method_body        = execute_block.body
          @in_execute_block           = true
          emit_indent
          emit(execute_block.body)
          emit_newline
          @in_execute_block           = false
          @typed_locals               = {}
          @typed_array_locals         = {}
          @current_class_locals       = {}
          @current_local_array_elems  = {}
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

        const_locs = scope.instance_variable_get(:@constants_locations) || {}
        scope.instance_variable_get(:@constants_table)&.each do |name, value|
          next unless value.is_a?(Vm::ModuleObject)
          next if SKIP_CONSTANTS.include?(name)
          emit_user_class(name, value, const_loc: const_locs[name])
          emit_user_classes(value, visited)
        end
      end

      def emit_user_class(name, mod, const_loc: nil)
        # For Struct subclasses: include initialize (it's defined in core but
        # we need it for the Crystal class to work)
        is_struct = mod.is_a?(Vm::ClassObject) && struct_subclass?(mod)
        user_methods = mod.instance_variable_get(:@methods_table)&.select do |_n, m|
          m.is_a?(Vm::Method) &&
            (user_source_location?(m.source_location) || accessor_method?(m) ||
             (is_struct && _n == :initialize))
        end
        user_methods ||= {}
        has_user_methods = user_methods.any? { |_, m| user_source_location?(m.source_location) }
        # Emit if: has user methods, OR the class constant was defined in user code
        # (catches empty subclasses like `class B < A; end`)
        return unless has_user_methods || user_source_location?(const_loc)

        crystal_name = crystal_constant(name)
        is_class = mod.is_a?(Vm::ClassObject)
        kw = is_class ? "class" : "module"

        sc = is_class ? mod.instance_variable_get(:@superclass) : nil
        sc_name = sc&.instance_variable_get(:@name)

        write "#{kw} Ruby_#{crystal_name}"
        if sc_name && !%i[Object BasicObject Struct Data].include?(sc_name)
          write " < Ruby_#{crystal_constant(sc_name)}"
        elsif is_class
          write " < RubyObject"
        end
        emit_newline

        old_class_ivars       = @current_class_ivars
        old_class_typed_ivars = @current_class_typed_ivars
        old_class_name        = @current_class_name
        @current_class_ivars       = @typed_ivars.fetch(name, {})
        @current_class_typed_ivars = @class_typed_ivars.fetch(name, {})
        @current_class_name        = name

        indented do
          # Collect and emit ivar declarations (Crystal requires them upfront)
          all_ivars = []
          user_methods.each do |_mname, method|
            all_ivars |= collect_ivars(method.body) if method.body
          end
          all_ivars.each do |iv|
            emit_indent
            iv_sym = iv.to_sym
            type_ann, default = case @current_class_ivars[iv_sym]
              when :f64 then ["Float64", "0.0_f64"]
              when :i64 then ["Int64",   "0_i64"]
              else
                ct = @current_class_typed_ivars[iv_sym]
                if ct
                  kind, cls = ct
                  crystal_cls = "Ruby_#{crystal_constant(cls)}"
                  if kind == :class_or_nil
                    ["#{crystal_cls} | RubyNil", "RUBY_NIL"]
                  else
                    [crystal_cls, "RUBY_NIL"]
                  end
                else
                  ["RubyObject", "RUBY_NIL"]
                end
            end
            line "#{iv} : #{type_ann} = #{default}"
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

          # Emit module/class-level constants
          emit_user_constants(mod)
          emit_newline

          user_methods.each do |mname, method|
            emit_indent
            if accessor_method?(method)
              emit_accessor_method(mname, method)
            else
              inst_param_types = @ti_class_params[[name, mname]]
              emit_vm_method(mname, method, param_types: inst_param_types)
              emit_newline
              emit_newline
            end
          end

          # Emit class/module methods (def self.x) from the eigenclass
          eigenclass = mod.instance_variable_get(:@eigenclass)
          if eigenclass
            class_methods = eigenclass.instance_variable_get(:@methods_table)&.select do |_n, m|
              m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            end
            (class_methods || {}).each do |mname, method|
              emit_indent
              emit_vm_method(mname, method, class_method: true)
              emit_newline
              emit_newline
            end
          end

          # Emit respond_to? — closed-world boolean lookup of all methods
          emit_respond_to(mod) if is_class
        end

        @current_class_ivars       = old_class_ivars
        @current_class_typed_ivars = old_class_typed_ivars
        @current_class_name        = old_class_name
        emit_indent
        write "end"
        emit_newline

      end

      # Emit respond_to? as a closed-world method-presence lookup.
      # Walks the class's ancestor chain to collect all method names.
      def emit_respond_to(klass)
        all_methods = Set.new
        c = klass
        while c && c.is_a?(Vm::ClassObject)
          (c.instance_variable_get(:@methods_table) || {}).each_key { |m| all_methods << m }
          c.modules.each do |mod|
            (mod.instance_variable_get(:@methods_table) || {}).each_key { |m| all_methods << m }
          end
          c = c.superclass
        end
        # Remove internal/bootstrap methods, keep public-facing ones
        all_methods.delete(:initialize)

        emit_indent
        line "def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool"
        indented do
          emit_indent
          write "n = name.is_a?(RubySymbol) ? name.to_s : name.to_s"
          emit_newline
          emit_indent
          write "case n"
          emit_newline
          # Emit method names in sorted order for readability
          all_methods.map(&:to_s).sort.each_slice(8) do |batch|
            emit_indent
            write "when #{batch.map { |m| m.inspect }.join(', ')}"
            emit_newline
            indented { emit_indent; write "RUBY_TRUE" }
            emit_newline
          end
          emit_indent
          write "else"
          emit_newline
          indented { emit_indent; write "RUBY_FALSE" }
          emit_newline
          emit_indent
          write "end"
        end
        emit_newline
        emit_indent
        line "end"
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Emit user-defined top-level methods
      # -----------------------------------------------------------------------

      def emit_user_top_level_methods(scope)
        scope.instance_variable_get(:@methods_table)&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)

          if opt?(:method_specialization) && @typed_params[name] && @typed_method_returns[name]
            emit_indent
            emit_specialized_vm_method(name, method)
            emit_newline
            emit_newline
          end

          emit_indent
          # If a specialized raw overload exists, the generic must use RubyObject params
          # to avoid conflicting with the Int64/Float64 overload (Crystal picks last def).
          generic_params = @typed_params[name] ? nil : @inferred_params[name]
          emit_vm_method(name, method, param_types: generic_params)
          emit_newline
          emit_newline
        end
      end

      # Emit a Crystal method definition from a Vm::Method object.
      # Vm::Method has the same ivar names as Ast::MethodDef, so we can pass
      # it directly to emit_param_list (which uses ivar/instance_variable_get).
      def emit_vm_method(name, method, param_types: nil, class_method: false)
        old_typed      = @typed_locals
        old_typed_arrs = @typed_array_locals
        old_local_elem = @current_local_array_elems
        old_block_params = @current_block_params
        param_names = (ivar(method, :required_params) || []) +
                      (ivar(method, :optional_params) || []).map(&:first) +
                      [ivar(method, :rest_param)].compact +
                      (ivar(method, :post_params) || [])
        param_set = param_names.to_set
        mkey = @current_class_name ? [@current_class_name, name] : name
        # Use TypeInference results for local types (omit params — they have declared types)
        @typed_locals              = opt?(:unbox_locals)    ? ((@ti_locals[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @typed_array_locals        = opt?(:native_arrays)   ? ((@ti_arrays[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @current_class_locals      = opt?(:devirtualize)    ? ((@ti_class_locals[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @current_local_array_elems = opt?(:native_arrays)   ? ((@ti_local_array_elems[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @current_block_params      = (@ti_block_params[mkey]      || {}).reject { |k, _| param_set.include?(k) }
        @current_local_2d_arrays   = opt?(:native_2d_arrays) ? detect_local_2d_arrays(method.body, param_set) : {}
        @current_method_body       = method.body
        @native_array_locals       = {}
        # Include raw-typed params in @typed_locals so node_raw_type works for them
        # and they are correctly boxed/unboxed in mixed expressions.
        if param_types
          req = ivar(method, :required_params) || []
          req.each_with_index do |p, i|
            case param_types[i]
            when 'Int64'        then @typed_locals[p] = :i64
            when 'Float64'      then @typed_locals[p] = :f64
            when 'Array(Int64)' then @native_array_locals[p] = :i64
            when 'Array(Float64)' then @native_array_locals[p] = :f64
            end
          end
        end
        # Infer types from literal assignments for locals TI didn't cover
        infer_local_types(method.body).each do |lname, ty|
          @typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
        string_return = STRING_RETURN_METHODS.include?(name)
        crystal_name  = string_return ? name.to_s : crystal_method_name(name)

        # If method has a typed return but no fully-typed-params overload,
        # emit with raw body and return type annotation.
        raw_return = opt?(:raw_returns) && !@typed_params[name] && @typed_method_returns[name]
        cr_return_types = { i64: 'Int64', f64: 'Float64' }

        write class_method ? "def self.#{crystal_name}" : "def #{crystal_name}"
        write " : String" if string_return
        emit_param_list(method, param_types: param_types)
        write " : #{cr_return_types[raw_return]}" if raw_return
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
        elsif raw_return
          indented { emit_raw_body(method.body) }
        else
          indented { emit(method.body) }
        end

        emit_newline
        emit_indent
        write "end"
      ensure
        @typed_locals              = old_typed
        @typed_array_locals        = old_typed_arrs
        @current_class_locals      = {}
        @current_local_array_elems = old_local_elem
        @current_block_params      = old_block_params
        @raw_block_params          = {}
        @current_local_2d_arrays   = {}
        @native_array_locals       = {}
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
        when Vm::FloatObject   then "RubyFloat.new(#{float_bits_expr(value.raw)})"
        when Vm::StringObject  then "RubyString.new(#{value.raw.inspect})"
        when Vm::NilObject     then "RUBY_NIL"
        when Vm::TrueObject    then "RUBY_TRUE"
        when Vm::FalseObject   then "RUBY_FALSE"
        when Vm::SymbolObject  then "RubySymbol.new(#{value.raw.inspect})"
        when Vm::ArrayObject
          elems = value.raw.map { |e| vm_value_to_crystal(e) }
          return nil if elems.any?(&:nil?)
          "RubyArray.new([#{elems.join(', ')}] of RubyObject)"
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

      # -----------------------------------------------------------------------
      # Whole-program type inference (replaces all ad-hoc pre-passes)
      # -----------------------------------------------------------------------

      def run_type_inference(execute_block, top_level_scope)
        require_relative 'type_inference'

        user_methods_hash = {}
        top_level_scope.instance_variable_get(:@methods_table)&.each do |name, m|
          user_methods_hash[name] = m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end
        user_classes_hash = {}
        collect_user_classes_recursive(top_level_scope, user_classes_hash)
        @ti_user_class_names = user_classes_hash.keys.to_set

        all_constants = top_level_scope.instance_variable_get(:@constants_table) || {}
        ti  = TypeInference.new(
          user_methods:  user_methods_hash,
          user_classes:  user_classes_hash,
          execute_block: execute_block,
          constants:     all_constants.dup
        )
        env = ti.run

        # Unpack TypeEnv slots into codegen lookup structures
        env.instance_variable_get(:@slots).each do |slot, ty|
          next if ty == :unknown || !slot.is_a?(Array)
          kind = slot[0]
          case kind
          when :local
            if ty.is_a?(Hash) && opt?(:devirtualize)
              (@ti_class_locals[slot[1]] ||= {})[slot[2]] = ty[:class] if @ti_user_class_names&.include?(ty[:class])
            end
            if ty.is_a?(Hash) && ty[:class] == :Array && opt?(:native_arrays) && (elem_raw = ti_raw_type(ty[:elem]))
              (@ti_local_array_elems[slot[1]] ||= {})[slot[2]] = elem_raw
            end
            next unless opt?(:unbox_locals)
            raw = ti_raw_type(ty) or next
            (@ti_locals[slot[1]] ||= {})[slot[2]] = raw
          when :block_param
            next unless opt?(:native_iteration)
            raw = ti_raw_type(ty) or next
            (@ti_block_params[slot[1]] ||= {})[slot[2]] = raw
          when :array_elem
            next unless opt?(:native_arrays)
            raw = ti_raw_type(ty) or next
            (@ti_arrays[slot[1]] ||= {})[slot[2]] = raw
          when :const
            next unless opt?(:unbox_locals)
            raw = ti_raw_type(ty) or next
            @const_raw_types[slot[1]] = raw
          when :ivar
            next unless opt?(:typed_ivars)
            raw = ti_raw_type(ty) or next
            (@typed_ivars[slot[1]] ||= {})[slot[2]] = raw
          when :return
            next unless opt?(:method_specialization) || opt?(:raw_returns) || opt?(:accessor_inline)
            mkey = slot[1]
            raw  = ti_raw_type(ty) or next
            if mkey.is_a?(Symbol)
              @typed_method_returns[mkey] = raw
            elsif mkey.is_a?(Array) && mkey.size == 2
              cname, fname = mkey
              @instance_method_raw_returns[[cname, fname]] = raw if @ti_user_class_names&.include?(cname)
            end
          end
        end

        # Build @inferred_params and @typed_params for top-level methods
        (opt?(:call_site_types) || opt?(:method_specialization)) && user_methods_hash.each do |mname, method|
          req = method.instance_variable_get(:@required_params) || []
          next if req.empty?
          crystal_types = req.each_with_index.map { |_, i|
            ty = env[[:param, mname, i]]
            ty ? ti_crystal_type(ty) : 'RubyObject'
          }
          next unless crystal_types.any? { |t| t != 'RubyObject' }
          @inferred_params[mname] = crystal_types
          raw_types = req.each_with_index.map { |_, i| ti_raw_type(env[[:param, mname, i]]) }
          @typed_params[mname] = raw_types if raw_types.all? && @typed_method_returns[mname]
        end

        # Build @ti_class_params for instance methods
        user_classes_hash.each do |cname, klass|
          (klass.instance_variable_get(:@methods_table) || {}).each do |mname, method|
            next unless method.is_a?(Vm::Method)
            req = method.instance_variable_get(:@required_params) || []
            next if req.empty?
            mkey = [cname, mname]
            crystal_types = req.each_with_index.map { |_, i|
              ty = env[[:param, mkey, i]]
              ty ? ti_crystal_type(ty) : 'RubyObject'
            }
            @ti_class_params[mkey] = crystal_types if crystal_types.any? { |t| t != 'RubyObject' }
          end
        end
      end

      # Convert a TypeInference lattice value to a Crystal type annotation string.
      def ti_crystal_type(ty)
        case ty
        when :i64       then 'Int64'
        when :f64       then 'Float64'
        when :array_i64 then 'Array(Int64)'
        when :array_f64 then 'Array(Float64)'
        when Hash
          case ty[:class]
          when :Integer          then 'RubyInteger'
          when :Float            then 'RubyFloat'
          when :String           then 'RubyString'
          when :Symbol           then 'RubySymbol'
          when :NilClass         then 'RubyNil'
          when :TrueClass, :FalseClass then 'RubyBool'
          when :Array
            if ty[:elem] && (elem_raw = ti_raw_type(ty[:elem]))
              elem_raw == :f64 ? 'Array(Float64)' : 'Array(Int64)'
            else
              'RubyArray'
            end
          when :Hash             then 'RubyHash'
          when :Proc             then 'RubyProc'
          else
            cls = ty[:class]
            @ti_user_class_names&.include?(cls) ? "Ruby_#{crystal_constant(cls)}" : 'RubyObject'
          end
        else 'RubyObject'
        end
      end

      # Extract the raw (unboxed) Crystal numeric type from a TypeInference value.
      # Returns :i64, :f64, or nil.
      def ti_raw_type(ty)
        ty == :i64 || ty == :f64 ? ty : nil
      end

      # Combined element type for typed-array and native-array (2D parent) locals.

      # -----------------------------------------------------------------------
      # Legacy: Walk the execute block body, collecting call-site argument types for
      # every free (non-method, non-receiver) call to user-defined methods.
      # (Superseded by run_type_inference — kept for reference)
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
        req_kw = ivar(node, :required_kw_params) || []
        opt_kw = ivar(node, :optional_kw_params) || []
        kr = ivar(node, :kw_rest_param)
        if (!req_kw.empty? || !opt_kw.empty?) && !rp
          parts << "*"  # Crystal keyword-only separator
        end
        req_kw.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        opt_kw.each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        parts << "**#{crystal_local(kr)}" if kr
        bp = ivar(node, :block_param)
        parts << "&#{crystal_local(bp)}" if bp
        write "(#{parts.join(', ')})" unless parts.empty?
      end

      # Override: for typed locals in boxed context, wrap in RubyInteger/RubyFloat.
      def emit_local_var_read(node)
        name = ivar(node, :name)
        case @typed_locals[name]
        when :i64 then write "RubyInteger.new(#{crystal_local(name)})"
        when :f64 then write "RubyFloat.new(#{crystal_local(name)})"
        else
          case @raw_block_params[name]
          when :i64 then write "RubyInteger.new(#{crystal_local(name)})"
          when :f64 then write "RubyFloat.new(#{crystal_local(name)})"
          else super
          end
        end
      end

      # Override: for typed locals, emit RHS as bare Crystal numeric.
      # For typed array locals, emit Array(T).new construction.
      # For class-typed locals, add .as(Ruby_ClassName) cast for static dispatch.
      def emit_local_var_write(node)
        name = ivar(node, :name)
        # 2D float array construction: c = Array.new(m) { Array.new(p, 0.0) }
        # Emit as Array(Array(Float64)).new(m) { Array(Float64).new(p, 0.0) }
        if (elem_raw = @current_local_2d_arrays[name])
          crystal_ty = elem_raw == :f64 ? "Float64" : "Int64"
          rhs  = ivar(node, :value_node)
          blk  = ivar(rhs, :block_node)
          outer_args = ivar(rhs, :arg_nodes) || []
          inner = ivar(blk, :body)
          inner = inner.nodes.first if inner.is_a?(Ast::Sequence) && inner.nodes.size == 1
          inner_args = ivar(inner, :arg_nodes) || []
          write "#{crystal_local(name)} = Array(Array(#{crystal_ty})).new("
          emit_coerce_i64(outer_args[0])
          write ") { Array(#{crystal_ty}).new("
          emit_coerce_i64(inner_args[0])
          write ", "
          emit_as(inner_args[1], elem_raw)
          write ") }"
          return
        end
        if (arr_ty = @typed_array_locals[name])
          rhs  = ivar(node, :value_node)
          args = ivar(rhs, :arg_nodes) || []
          crystal_ty = arr_ty == :f64 ? "Float64" : "Int64"
          write "#{crystal_local(name)} = Array(#{crystal_ty}).new("
          emit_coerce_i64(args[0])
          write ", "
          emit_as(args[1], arr_ty)
          write ")"
          return
        end
        # Promote boxed-array local to native Array(T) when initialized via Array.new(n, default).
        if (elem_ty = @current_local_array_elems[name]) && !@typed_array_locals.key?(name)
          rhs  = ivar(node, :value_node)
          if rhs.is_a?(Ast::MethodCall) && ivar(rhs, :name) == :new &&
             ivar(rhs, :receiver_node).is_a?(Ast::ConstantRead) &&
             ivar(ivar(rhs, :receiver_node), :name) == :Array
            args = ivar(rhs, :arg_nodes) || []
            if args.size == 2
              crystal_ty = elem_ty == :f64 ? "Float64" : "Int64"
              write "#{crystal_local(name)} = Array(#{crystal_ty}).new("
              emit_coerce_i64(args[0])
              write ", "
              emit_as(args[1], elem_ty)
              write ")"
              @native_array_locals[name] = elem_ty
              return
            end
          end
        end
        if (raw_ty = @typed_locals[name])
          write "#{crystal_local(name)} = "
          emit_as(ivar(node, :value_node), raw_ty)
          return
        end
        if @current_local_array_elems.key?(name)
          # Check if RHS is a read from a 2D native array: ci = c[i]
          value = ivar(node, :value_node)
          if value.is_a?(Ast::MethodCall) && ivar(value, :name) == :[] &&
             (vargs = ivar(value, :arg_nodes) || []).size == 1 &&
             ivar(value, :receiver_node).is_a?(Ast::LocalVariableRead) &&
             @current_local_2d_arrays.key?(ivar(ivar(value, :receiver_node), :name))
            # Emit: ci = c[raw_i]  (Crystal infers ci : Array(Float64))
            write "#{crystal_local(name)} = "
            emit(value)
            @native_array_locals[name] = @current_local_array_elems[name]
            return
          end
          write "#{crystal_local(name)} = "
          emit(ivar(node, :value_node))
          write ".as(RubyArray)"
          return
        end
        if (cls = @current_class_locals[name])
          write "#{crystal_local(name)} = "
          emit(ivar(node, :value_node))
          write ".as(Ruby_#{crystal_constant(cls)})"
          return
        end
        super
      end

      # Override: emit small fixed-size array literals as RubyTupleN (single
      # allocation, N inline fields) instead of RubyArray (3 allocations).
      MAX_TUPLE_SIZE = 8

      def emit_array_literal(node)
        return super unless opt?(:tuple_literals)
        elems = ivar(node, :element_nodes) || []
        if elems.size >= 1 && elems.size <= MAX_TUPLE_SIZE &&
           elems.none? { |e| e.is_a?(Ast::SplatArg) }
          write "RubyTuple#{elems.size}.new("
          elems.each_with_index do |el, i|
            write ", " if i > 0
            emit(el)
          end
          write ")"
        else
          super
        end
      end

      # Override: for typed ivars in boxed context, wrap in RubyFloat/RubyInteger.
      def emit_ivar_read(node)
        case @current_class_ivars[ivar(node, :name)]
        when :f64 then write "RubyFloat.new(#{ivar(node, :name)})"
        when :i64 then write "RubyInteger.new(#{ivar(node, :name)})"
        else super
        end
      end

      # Override: for typed ivars, coerce RHS to the raw type.
      def emit_ivar_write(node)
        iv_name = ivar(node, :name)
        return super unless (ty = @current_class_ivars[iv_name])
        write "#{iv_name} = "
        emit_as(ivar(node, :value_node), ty)
      end

      # Override: for index op-write (ci[j] += ...) with a raw-typed index,
      # emit the index temp as bare Int64 so the Int64 array overload is used.
      def emit_index_op_write(node)
        idx = ivar(node, :index_arg_nodes)&.first
        op        = ivar(node, :operator)
        recv_node = ivar(node, :receiver_node)
        val_node  = ivar(node, :value_node)
        # Native Array(T) receiver: emit arr[i] op= val directly, coercing index to Int64
        recv_name = recv_node.is_a?(Ast::LocalVariableRead) && ivar(recv_node, :name)
        if recv_name && (nat_ty = native_array_elem_type(recv_name))
          write "#{crystal_local(recv_name)}["
          emit_coerce_i64(idx)
          write "] #{op}= "
          emit_as(val_node, nat_ty)
          return
        end
        return super unless idx && node_raw_type(idx)
        r = "_iopw_r#{@temp_counter}"
        i = "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        write "(#{r} = "
        recv_node ? emit(recv_node) : write("self")
        write "; #{i} = "
        emit_raw(idx)
        # If the receiver array has a known scalar element type, emit raw arithmetic
        # and rebox on write to avoid RubyFloat#op dispatch overhead.
        recv_elem_ty = recv_node.is_a?(Ast::LocalVariableRead) &&
                       @current_local_array_elems[ivar(recv_node, :name)]
        if recv_elem_ty
          unbox = recv_elem_ty == :f64 ? ".as(RubyFloat).to_f64" : ".as(RubyInteger).to_i64"
          box   = recv_elem_ty == :f64 ? "RubyFloat" : "RubyInteger"
          write "; #{r}[#{i}] = #{box}.new(#{r}[#{i}]#{unbox} #{op} "
          emit_as(val_node, recv_elem_ty)
          write "))"
        else
          write "; #{r}[#{i}] = (#{r}[#{i}] #{op} "
          emit(val_node)
          write "))"
        end
      end

      # Override: for [] with a raw-typed index, pass Int64 directly.
      # Also intercepts free calls to typed-param/return methods with all-raw args.
      # Emit call args where each arg is emitted raw (if param type is Int64/Float64)
      # or boxed (otherwise). param_types is an array of Crystal type strings.
      def emit_typed_call_args(args, param_types)
        write "("
        args.each_with_index do |arg, i|
          write ", " if i > 0
          pt = param_types[i]
          if (pt == 'Int64' || pt == 'Float64') && node_raw_type(arg)
            emit_raw(arg)
          else
            emit(arg)
          end
        end
        write ")"
      end

      def emit_method_call(node)
        # Array.new(n) { |i| body } with all-integer block params →
        # use the native Int64 overload so params are raw in the block body.
        if node.name == :new &&
           node.receiver_node.is_a?(Ast::ConstantRead) &&
           ivar(node.receiver_node, :name) == :Array &&
           node.block_node.is_a?(Ast::Block)
          blk    = node.block_node
          params = ivar(blk, :required_params) || []
          args   = node.arg_nodes || []
          if !params.empty? &&
             params.all? { |p| p.is_a?(Symbol) && @current_block_params[p] == :i64 } &&
             args.size == 1 && node_raw_type(args[0]) == :i64
            write "RubyArray.new("
            emit_raw(args[0])
            write ") { |"
            write params.map { |p| crystal_local(p) }.join(", ")
            write "|"
            emit_newline
            old_rbp = @raw_block_params
            @raw_block_params = old_rbp.merge(params.map { |p| [p, :i64] }.to_h)
            indented { emit_native_block_body(ivar(blk, :body)) }
            @raw_block_params = old_rbp
            emit_newline
            emit_indent
            write "}"
            return
          end
        end

        # Native Crystal integer iteration: n.times/upto/downto { block }
        # when receiver is raw i64 — avoids Frozone's Ruby method dispatch.
        if opt?(:native_iteration) && node.block_node && !node.block_node.is_a?(Ast::BlockArg) &&
           (node.arg_nodes || []).size <= 1 &&
           node_raw_type(node.receiver_node) == :i64
          case node.name
          when :times
            emit_raw(node.receiver_node)
            write ".times "
            emit_native_iter_block(node.block_node)
            return
          when :upto
            limit = (node.arg_nodes || [])[0]
            if limit && node_raw_type(limit) == :i64
              write "("
              emit_raw(node.receiver_node)
              write ".."
              emit_raw(limit)
              write ").each "
              emit_native_iter_block(node.block_node)
              return
            end
          when :downto
            limit = (node.arg_nodes || [])[0]
            if limit && node_raw_type(limit) == :i64
              write "("
              emit_raw(limit)
              write ".."
              emit_raw(node.receiver_node)
              write ").reverse_each "
              emit_native_iter_block(node.block_node)
              return
            end
          end
        end

        # Typed instance method call on a known-class receiver local:
        # emit args raw where the param type is Int64/Float64.
        if node.receiver_node.is_a?(Ast::LocalVariableRead)
          recv_name  = ivar(node.receiver_node, :name)
          recv_class = @current_class_locals[recv_name]
          if recv_class && (tp = @ti_class_params[[recv_class, node.name]])
            emit(node.receiver_node)
            write ".#{crystal_method_name(node.name)}"
            emit_typed_call_args(node.arg_nodes || [], tp)
            return
          end
        end

        # Typed/native array read in boxed context: box the Int64/Float64 element
        if node.name == :[] && node.receiver_node&.is_a?(Ast::LocalVariableRead) &&
           (arr_ty = native_array_elem_type(ivar(node.receiver_node, :name))) &&
           node.arg_nodes&.size == 1
          box_fn = arr_ty == :f64 ? "RubyFloat" : "RubyInteger"
          write "#{box_fn}.new(#{crystal_local(ivar(node.receiver_node, :name))}["
          emit_coerce_i64(node.arg_nodes[0])
          write "])"
          return
        end

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

        # Free call to method with typed params — coerce args to declared types
        if node.receiver_node.nil? && (tp = @inferred_params[node.name])
          write crystal_method_name(node.name)
          emit_typed_call_args(node.arg_nodes || [], tp)
          return
        end

        # Devirtualize: cast class-typed receiver locals so Crystal sees the
        # Devirtualize: cast class-typed receiver locals so Crystal sees the
        # concrete type and can inline/devirtualize the method call.
        if node.receiver_node.is_a?(Ast::LocalVariableRead)
          recv_name  = ivar(node.receiver_node, :name)
          recv_class = @current_class_locals[recv_name]
          if recv_class
            write "#{crystal_local(recv_name)}.as(Ruby_#{crystal_constant(recv_class)}).#{crystal_method_name(node.name)}"
            emit_call_args(node)
            return
          end
        end

        # Typed arithmetic/comparison: if both operands are raw-typed, emit
        # raw Crystal arithmetic instead of going through RubyObject dispatch.
        if node.receiver_node && (node.arg_nodes || []).size == 1 &&
           (ARITH_OPS_UNBOX | CrystalCodegen::COMPARE_OPS).include?(node.name)
          rt = node_raw_type(node.receiver_node)
          at = node_raw_type(node.arg_nodes[0])
          if rt || at
            ty = (rt == :f64 || at == :f64) ? :f64 : :i64
            if CrystalCodegen::COMPARE_OPS.include?(node.name)
              write "(("
              emit_as(node.receiver_node, ty)
              op = (node.name == :/ && ty == :i64) ? "//" : node.name.to_s
              write " #{op} "
              emit_as(node.arg_nodes[0], ty)
              write ") ? RUBY_TRUE : RUBY_FALSE)"
            else
              write "RubyInteger.new("  if ty == :i64
              write "RubyFloat.new("   if ty == :f64
              emit_as(node.receiver_node, ty)
              op = (node.name == :/ && ty == :i64) ? "//" : node.name.to_s
              write " #{op} "
              emit_as(node.arg_nodes[0], ty)
              write ")"
            end
            return
          end
        end

        super
      end

      # Override: for []= with typed array or raw-typed index, emit accordingly.
      def emit_attribute_write(node)
        if ivar(node, :name) == :[]=
          args = ivar(node, :arg_nodes)
          recv = ivar(node, :receiver_node)
          # Unboxed/native Array(T) write: emit value as bare native type
          if recv.is_a?(Ast::LocalVariableRead) &&
             (arr_ty = native_array_elem_type(ivar(recv, :name))) &&
             args&.size == 2
            write "#{crystal_local(ivar(recv, :name))}["
            emit_coerce_i64(args[0])
            write "] = "
            emit_as(args[1], arr_ty)
            return
          end
          # Boxed RubyArray with known elem type: box raw value on write
          if recv.is_a?(Ast::LocalVariableRead) &&
             (elem_ty = @current_local_array_elems[ivar(recv, :name)]) &&
             args&.size == 2 && node_raw_type(args[1])
            box = elem_ty == :f64 ? "RubyFloat" : "RubyInteger"
            emit(recv)
            write "["
            emit_coerce_i64(args[0])
            write "] = #{box}.new("
            emit_raw(args[1])
            write ")"
            return
          end
          # Non-typed array with raw-typed index: use Int64 overload
          if node_raw_type(args&.first)
            emit(recv)
            write "["
            emit_raw(args[0])
            write "] = "
            emit(args[1])
            return
          end
        end
        super
      end

      # Override: for comparisons with at least one raw-typed operand, use bare
      # Crystal comparison with .to_i64/.to_f64 coercion on the untyped side.
      def emit_truthy(node)
        if opt?(:condition_simplify) && comparison_op_call?(node)
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

      # Override: coerce typed ivar targets in multiple assignment.
      # Override: when all targets are typed locals and RHS is an ArrayLiteral,
      # emit direct raw assignments instead of masgn_coerce(RubyArray.new([...])).
      def emit_multiple_assignment(node)
        targets = ivar(node, :targets)
        rhs     = ivar(node, :value_node)

        # Fast path: no splat, all targets are typed locals, RHS is ArrayLiteral
        has_splat = targets.any? { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if !has_splat && rhs.is_a?(Ast::ArrayLiteral)
          elems = ivar(rhs, :element_nodes) || []
          all_typed = targets.all? do |t|
            t[0] == :local && (
              @typed_locals[t[1]] ||
              @typed_array_locals[t[1]] ||
              @current_class_locals[t[1]]
            )
          end
          if all_typed && elems.size >= targets.size
            targets.each_with_index do |t, i|
              emit_newline unless i == 0
              emit_indent unless i == 0
              name   = t[1]
              elem   = elems[i]
              if (raw_ty = @typed_locals[name])
                write "#{crystal_local(name)} = "
                emit_as(elem, raw_ty)
              elsif (cls = @current_class_locals[name])
                write "#{crystal_local(name)} = "
                emit(elem)
                write ".as(Ruby_#{crystal_constant(cls)})"
              else
                # typed array local — fall back to super for this case
                return super
              end
            end
            return
          end
        end

        super
      end

      def emit_masgn_assign(target, value_code)
        if target[0] == :ivar && (ty = @current_class_ivars[target[1]])
          coerce = ty == :f64 ? ".to_f64" : ".to_i64"
          write "#{target[1]} = #{value_code}#{coerce}"
        elsif (target[0] == :local || target[0] == :local_splat) &&
              (ty = @typed_locals[target[1]])
          coerce = ty == :f64 ? ".to_f64" : ".to_i64"
          write "#{crystal_local(target[1])} = #{value_code}#{coerce}"
        elsif (target[0] == :index || target[0] == :index_splat) &&
              target[1].is_a?(Ast::LocalVariableRead) &&
              (nat_ty = native_array_elem_type(ivar(target[1], :name)))
          # Native Array(T) index write: coerce index to Int64 and value to T
          coerce = nat_ty == :f64 ? ".to_f64" : ".to_i64"
          write "#{crystal_local(ivar(target[1], :name))}["
          target[2].each_with_index do |idx, i|
            write ", " if i > 0
            emit_coerce_i64(idx)
          end
          write "] = #{value_code}#{coerce}"
        else
          super
        end
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

      def struct_subclass?(klass)
        c = klass
        while c && c.is_a?(Vm::ClassObject)
          return true if c.name == :Struct
          c = c.superclass
        end
        false
      end

      # Emit an accessor method as an efficient one-liner.
      # For typed ivars, box (getter) or coerce (setter) at the RubyObject boundary.
      # Also emits a `<name>_raw` raw-typed getter for typed ivars (avoids box allocation).
      def emit_accessor_method(mname, method)
        body = method.body
        case body
        when Ast::InstanceVariableRead
          iv = ivar(body, :name)
          case @current_class_ivars[iv]
          when :f64
            line "def #{crystal_method_name(mname)} : RubyObject; RubyFloat.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Float64; #{iv}; end"
          when :i64
            line "def #{crystal_method_name(mname)} : RubyObject; RubyInteger.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Int64; #{iv}; end"
          else
            ct = @current_class_typed_ivars[iv]
            if ct
              kind, cls = ct
              ret_type = kind == :class_or_nil ? "Ruby_#{crystal_constant(cls)} | RubyNil" : "Ruby_#{crystal_constant(cls)}"
              line "def #{crystal_method_name(mname)} : #{ret_type}; #{iv}; end"
            else
              line "def #{crystal_method_name(mname)} : RubyObject; #{iv}; end"
            end
          end
        when Ast::InstanceVariableWrite
          iv = ivar(body, :name)
          case @current_class_ivars[iv]
          when :f64
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_f64; v; end"
          when :i64
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_i64; v; end"
          else
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v; end"
          end
        end
      end
    end
  end
end
