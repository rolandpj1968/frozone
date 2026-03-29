require_relative 'crystal_emitter'
require_relative 'crystal_type'
require_relative 'crystal_type_mapper'
require_relative 'type_inference'
require_relative 'method_context'
require_relative '../vm/module_object'
require_relative '../vm/method'
require_relative 'codegen/raw_emission'
require_relative 'codegen/array_analysis'
require_relative 'codegen/ivar_analysis'
require_relative 'codegen/method_specialisation'

module Frozone
  module Compiler
    # Snapshot-based Crystal code generator.
    #
    # Unlike CrystalEmitter (which is driven by a raw source AST), Codegen
    # is driven by the *settled* Frozone VM state after the load phase has run:
    #
    #   1. Walk Core::OBJECT_CLASS to find user-defined top-level methods and classes.
    #   2. Serialise settled non-class constants (N=200, etc.) to Crystal initializers.
    #   3. Emit the execute-phase block body (from Frozone.compile! { ... }) as main.
    #
    # "User-defined" is determined by source_location: methods/constants whose
    # location does not fall inside lib/core/ or lib/frozone/ are user code.
    class Codegen < CrystalEmitter
      include CodegenSupport::ArrayAnalysis
      include CodegenSupport::RawEmission
      include CodegenSupport::IvarAnalysis
      include CodegenSupport::MethodSpecialisation

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
        1 => %i[tuple_literals devirtualize condition_simplify
                native_iteration accessor_inline],
        2 => OPT_FLAGS.dup
      }.freeze

      def opt?(flag) = @opt_flags.include?(flag)

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
        @mctx = MethodContext.new  # per-method emission state (replaced per emit_vm_method)
        @inferred_params             = {}
        @typed_params                = {}
        @typed_method_returns        = {}
        @instance_method_raw_returns = {}
        @const_raw_types             = {}
        @typed_ivars                 = {}
        @class_typed_ivars           = {}
        @current_class_ivars         = {}
        @current_class_typed_ivars   = {}
        @current_class_name          = nil
        @ti_locals                   = {}
        @ti_arrays                   = {}
        @ti_class_locals             = {}
        @ti_local_array_elems        = {}
        @ti_block_params             = {}
        @ti_class_params             = {}
        @ti_local_types              = {}
        @mctx.emit_crystal_tuple          = false # true when emitting last expression of method body (multi-return)
        @masgn_return_methods        = nil   # Set of method names called in masgn RHS position
        @object_instance_methods     = Set.new # methods emitted on RubyObject (skip *args stubs)
        @suppress_tuple_literals     = false  # true inside local var assignment (arrays may be mutated)

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

        # Whole-program type inference (replaces all ad-hoc pre-passes)
        run_type_inference(execute_block, top_level_scope)

        # Pre-scan: find methods on Object that will get real instance method
        # implementations on RubyObject (so we skip *args stubs for them).
        top_level_scope.instance_variable_get(:@methods_table)&.each do |name, m|
          @object_instance_methods << name if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end

        emit_header
        emit_bench_harness_require if bench_stub?
        emit_user_method_stubs unless @user_methods.empty?

        # Collect class-typed ivars (X | nil patterns) across all methods
        collect_class_typed_ivars(top_level_scope) if opt?(:ivar_narrowing)

        # Scan for methods called in masgn RHS (multi-return → Crystal tuple)
        @masgn_return_methods = collect_masgn_return_methods(execute_block&.body, top_level_scope)

        # Build global method-name → index map for respond_to? bit arrays.
        build_method_index(top_level_scope)
        emit_method_index_table

        # User-defined classes and modules (from the constant table)
        emit_user_classes(top_level_scope)

        # User-defined top-level methods (private methods on Object defined in user code)
        emit_user_top_level_methods(top_level_scope)

        # Settled non-class constants
        emit_user_constants(top_level_scope)

        # Serialize settled global variable values from load phase
        emit_global_initializers(globals)

        # Execute phase — the block body
        if execute_block
          @mctx = MethodContext.new
          @mctx.typed_locals      = opt?(:unbox_locals) ? (@ti_locals[nil] || {}) : {}
          @mctx.typed_array_locals = opt?(:native_arrays) ? (@ti_arrays[nil] || {}) : {}
          @mctx.class_locals      = opt?(:devirtualize) ? (@ti_class_locals[nil] || {}) : {}
          @mctx.local_array_elems = opt?(:native_arrays) ? (@ti_local_array_elems[nil] || {}) : {}
          @mctx.block_params      = @ti_block_params[nil] || {}
          @mctx.local_types       = @ti_local_types[nil] || {}
          @mctx.method_body       = execute_block.body
          @in_execute_block       = true
          emit_indent
          emit(execute_block.body)
          emit_newline
          @in_execute_block = false
        end

        @out
      end

      private

      # -----------------------------------------------------------------------
      # Source-location filtering
      # -----------------------------------------------------------------------

      def bench_stub? = @stub_file&.include?('bench/stubs/')

      # Resolve a receiver AST node to a known class Symbol (from TI devirtualize).
      def receiver_known_class(recv)
        return nil unless recv.is_a?(Ast::LocalVariableRead)
        @mctx.class_locals[ivar(recv, :name)]
      end

      # Look up a VM class/module by name in the top-level constant table.
      def lookup_vm_class(name)
        val = @top_level_scope.instance_variable_get(:@constants_table)&.fetch(name, nil)
        val.is_a?(Vm::ModuleObject) ? val : nil
      end

      def user_source_location?(loc)
        return false if loc.nil?
        # source_location is "file:line" — strip the :line suffix for comparison
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @stub_file && file == @stub_file
        CORE_PATH_MARKERS.none? { |marker| file.include?(marker) }
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
                  crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
                  if kind == :class_or_nil
                    ["#{crystal_cls} | RubyNil", "RUBY_NIL"]
                  else
                    # Non-nullable: provide a valid default
                    default = case cls
                              when :Array  then "RubyArray.new"
                              when :Hash   then "RubyHash.new"
                              when :String then "RubyString.new"
                              else "RUBY_NIL"
                              end
                    # Fall back to nullable if we can't provide a default
                    default == "RUBY_NIL" ? ["#{crystal_cls} | RubyNil", "RUBY_NIL"] : [crystal_cls, default]
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

          # Collect eigenclass method names for dispatch and dedup
          eigenclass = mod.instance_variable_get(:@eigenclass)
          @current_class_eigen_methods = nil
          eigen_method_names = if eigenclass
            (eigenclass.instance_variable_get(:@methods_table) || {}).select { |_, m|
              m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            }.keys.to_set
          else
            Set.new
          end

          user_methods.each do |mname, method|
            # Skip instance methods that are duplicated as class methods
            # (from module_function) — the class method version is typed
            next if eigen_method_names.include?(mname) && mname != :initialize
            emit_indent
            if accessor_method?(method)
              emit_accessor_method(mname, method)
            else
              inst_param_types = @ti_class_params[[name, mname]]
              has_typed = inst_param_types&.any? { |t| t && t != :ruby_object }
              if has_typed
                # Emit typed overload first, then generic (RubyObject) fallback
                emit_vm_method(mname, method, param_types: inst_param_types)
                emit_newline
                emit_newline
                emit_indent
                emit_vm_method(mname, method)  # generic
              else
                emit_vm_method(mname, method, param_types: inst_param_types)
              end
              emit_newline
              emit_newline
            end
          end

          # Emit class/module methods (def self.x) from the eigenclass
          @current_class_eigen_methods = eigen_method_names
          if eigenclass
            class_methods = eigenclass.instance_variable_get(:@methods_table)&.select do |_n, m|
              m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            end
            (class_methods || {}).each do |mname, method|
              # Check both class-keyed and free-call-keyed params
              class_param_types = @ti_class_params[[name, mname]] || @inferred_params[mname]
              # Emit specialized (typed) overload if params have raw types
              raw_types = class_param_types&.map { |t| CrystalType.raw(t) }
              class_return = @instance_method_raw_returns[[name, mname]]
              if opt?(:method_specialization) && raw_types&.any?
                emit_indent
                emit_specialized_class_method(name, mname, method, raw_types, class_return, crystal_param_types: class_param_types)
                emit_newline
                emit_newline
              end
              # Emit generic (RubyObject) overload — always present for boxed callers.
              # Use RubyObject params when a specialized overload exists, to avoid
              # conflicting with the typed overload.
              emit_indent
              generic_params = raw_types&.any? ? nil : class_param_types
              emit_vm_method(mname, method, param_types: generic_params, class_method: true)
              emit_newline
              emit_newline
            end
          end

          # Emit respond_to? — closed-world boolean lookup of all methods
          emit_respond_to(mod) if is_class
        end

        @current_class_ivars        = old_class_ivars
        @current_class_typed_ivars  = old_class_typed_ivars
        @current_class_name         = old_class_name
        @current_class_eigen_methods = nil
        emit_indent
        write "end"
        emit_newline

      end

      # Emit respond_to? as a closed-world method-presence lookup.
      # Walks the class's ancestor chain to collect all method names.
      # Collect ALL method names across ALL user classes and assign indices.
      # Index 0 is the sentinel (always-false for unknown method names).
      def build_method_index(scope)
        all_method_names = Set.new
        collect_all_method_names = ->(klass) {
          c = klass
          while c && c.is_a?(Vm::ClassObject)
            (c.instance_variable_get(:@methods_table) || {}).each_key { |m| all_method_names << m }
            c.modules.each do |mod|
              (mod.instance_variable_get(:@methods_table) || {}).each_key { |m| all_method_names << m }
            end
            c = c.superclass
          end
        }
        # Walk user classes
        (scope.instance_variable_get(:@constants_table) || {}).each_value do |val|
          collect_all_method_names.call(val) if val.is_a?(Vm::ClassObject)
        end
        # Also collect from Object (for top-level methods)
        collect_all_method_names.call(scope) if scope.is_a?(Vm::ClassObject)

        all_method_names.delete(:initialize)
        sorted = all_method_names.map(&:to_s).sort
        # Index 0 = sentinel (unknown method → always false)
        @method_name_index = { '__sentinel__' => 0 }
        sorted.each_with_index { |name, i| @method_name_index[name] = i + 1 }
      end

      def emit_method_index_table
        return if @method_name_index.size <= 1 # only sentinel
        line "# Global method-name → index for O(1) respond_to? lookup"
        line "FROZONE_METHOD_INDEX = {"
        @method_name_index.each do |name, idx|
          next if name == '__sentinel__'
          line "  #{name.inspect} => #{idx},"
        end
        line "}"
        emit_newline
      end

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
        all_methods.delete(:initialize)

        # Build bit array: index 0 (sentinel) is always false
        table_size = @method_name_index.size
        bits = Array.new(table_size, false)
        all_methods.each do |m|
          idx = @method_name_index[m.to_s]
          bits[idx] = true if idx
        end

        emit_indent
        line "  RESPOND_TO_TABLE = StaticArray[#{bits.map { |b| b.to_s }.join(', ')}]"
        emit_newline

        emit_indent
        line "def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool"
        indented do
          emit_indent
          write "idx = FROZONE_METHOD_INDEX.fetch(name.is_a?(RubySymbol) ? name.to_s : name.to_s, 0)"
          emit_newline
          emit_indent
          write "RESPOND_TO_TABLE[idx] ? RUBY_TRUE : RUBY_FALSE"
        end
        emit_newline
        emit_indent
        line "end"
        emit_newline
      end

      # Override: skip *args stubs for methods that get real implementations
      # on RubyObject (user methods defined on Object).
      def emit_user_method_stubs
        stubs = @user_methods.reject { |n|
          self.class.const_get(:RUBY_OBJECT_METHODS).include?(n) ||
            operator?(n) || @object_instance_methods.include?(n)
        }
        return if stubs.empty?
        write "# User-defined method stubs on RubyObject for polymorphic dispatch"
        emit_newline
        write "class RubyObject"
        emit_newline
        stubs.each do |name|
          crystal_name = crystal_method_name(name)
          params = crystal_name.end_with?('=') ? "(val : RubyObject)" : "(*args)"
          write "  def #{crystal_name}#{params} : RubyObject"
          emit_newline
          write "    raise Exception.new(\"undefined method '#{name}' for \#{self.class}\")"
          emit_newline
          write "  end"
          emit_newline
        end
        write "end"
        emit_newline
        emit_newline
      end

      # -----------------------------------------------------------------------
      # Emit user-defined top-level methods
      # -----------------------------------------------------------------------

      def emit_user_top_level_methods(scope)
        user_methods_on_object = []
        scope.instance_variable_get(:@methods_table)&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)
          user_methods_on_object << [name, method]

          if opt?(:method_specialization) && @typed_params[name] && @typed_method_returns[name]
            emit_indent
            emit_specialized_vm_method(name, method)
            emit_newline
            emit_newline
          end

          # Emit typed overload when inferred params have complex types (Array, etc.)
          # that need a separate generic fallback for untyped callers.
          inferred = @inferred_params[name]
          has_complex_params = !@typed_params[name] && inferred&.any? { |t| complex_native_type?(t) }
          if has_complex_params
            emit_indent
            emit_vm_method(name, method, param_types: inferred)
            emit_newline
            emit_newline
          end

          emit_indent
          # Generic overload: genericise any Crystal-native param types to
          # RubyObject. Types that are already RubyObject subtypes stay as-is.
          generic_params = if has_complex_params
            inferred.map { |t| CrystalType.native?(t) ? :ruby_object : t }
          elsif @typed_params[name]
            nil
          else
            inferred
          end
          emit_vm_method(name, method, param_types: generic_params)
          emit_newline
          emit_newline
        end

        # Also emit as instance methods on RubyObject so receiver-based calls
        # (e.g., obj.should) dispatch correctly via Crystal's virtual dispatch.
        # This mirrors Ruby where Object methods are available both ways.
        # Track these so we skip generating *args stubs for them.
        @object_instance_methods = user_methods_on_object.map(&:first).to_set
        return if user_methods_on_object.empty?
        line "# User methods on Object — also available as instance methods"
        line "class RubyObject"
        user_methods_on_object.each do |name, method|
          emit_indent
          write "  "
          generic_params = @typed_params[name] ? nil : @inferred_params[name]
          emit_vm_method(name, method, param_types: generic_params)
          emit_newline
        end
        line "end"
        emit_newline
      end

      # Emit a Crystal method definition from a Vm::Method object.
      # Vm::Method has the same ivar names as Ast::MethodDef, so we can pass
      # it directly to emit_param_list (which uses ivar/instance_variable_get).
      def emit_vm_method(name, method, param_types: nil, class_method: false)
        old_mctx = @mctx
        @mctx = MethodContext.new
        param_names = (ivar(method, :required_params) || []) +
                      (ivar(method, :optional_params) || []).map(&:first) +
                      [ivar(method, :rest_param)].compact +
                      (ivar(method, :post_params) || [])
        param_set = param_names.to_set
        @mctx.param_set = param_set
        mkey = @current_class_name ? [@current_class_name, name] : name
        # For generic class method overloads with a specialized version,
        # disable ALL type optimizations (the specialized handles raw paths).
        generic_with_specialized = class_method && param_types.nil? &&
          @current_class_eigen_methods&.any? &&
          (@inferred_params[name] || @ti_class_params[[@current_class_name, name]])&.any? { |t| t != :ruby_object }
        # Use TypeInference results for local types (omit params — they have declared types)
        @mctx.suppress_typed_call_args  = generic_with_specialized
        @mctx.typed_locals              = (!generic_with_specialized && opt?(:unbox_locals)) ? ((@ti_locals[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.typed_array_locals        = opt?(:native_arrays)   ? ((@ti_arrays[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.class_locals      = opt?(:devirtualize)    ? ((@ti_class_locals[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.local_array_elems = opt?(:native_arrays)   ? ((@ti_local_array_elems[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.block_params      = (@ti_block_params[mkey]      || {}).reject { |k, _| param_set.include?(k) }
        @mctx.local_types       = (@ti_local_types[mkey] || {}).reject { |k, _| param_set.include?(k) }
        @mctx.method_body       = method.body
        @mctx.block_param_name  = ivar(method, :block_param)
        @mctx.native_array_locals       = {}
        # Detect nested Array.new(n) { Array.new(m, fill) } construction patterns
        if opt?(:native_arrays)
          detect_nested_array_locals(method.body, param_set).each do |lname, inner_elem|
            @mctx.native_array_locals[lname] = [:array, inner_elem]
          end
        end
        # Include raw-typed params in @mctx.typed_locals so node_raw_type works for them
        # and they are correctly boxed/unboxed in mixed expressions.
        if param_types
          req = ivar(method, :required_params) || []
          req.each_with_index do |p, i|
            pt = param_types[i]
            if CrystalType.scalar?(pt)
              @mctx.typed_locals[p] = pt
            elsif CrystalType.array?(pt)
              inner = CrystalType.elem(pt)
              @mctx.native_array_locals[p] = inner if CrystalType.native?(inner)
            end
          end
        end
        # Infer types from literal assignments for locals TI didn't cover.
        # Skip for generic class method overloads when a specialized version exists
        # (typed locals in the generic cause Float64/Int64 mismatches with RubyObject ops).
        has_specialized = class_method && @current_class_eigen_methods&.any? &&
          (@inferred_params[name] || @ti_class_params[[@current_class_name, name]])&.any? { |t| t != :ruby_object }
        unless has_specialized && param_types.nil?
          infer_local_types(method.body).each do |lname, ty|
            @mctx.typed_locals[lname] ||= ty unless param_set.include?(lname)
          end
        end
        string_return = STRING_RETURN_METHODS.include?(name)
        bool_return   = %i[== != < <= > >= equal?].include?(name) && !class_method
        crystal_name  = string_return ? name.to_s : crystal_method_name(name)

        # If method has a typed return but no fully-typed-params overload,
        # emit with raw body and return type annotation.
        # Skip for generic class method overloads when a specialized overload exists
        # (the specialized handles the raw return).
        has_specialized = class_method && @current_class_eigen_methods&.any? &&
          (@inferred_params[name] || @ti_class_params[[@current_class_name, name]])&.any? { |t| t != :ruby_object }
        raw_return = !has_specialized && opt?(:raw_returns) && !@typed_params[name] &&
          (@typed_method_returns[name] ||
           (@current_class_name && @instance_method_raw_returns[[@current_class_name, name]]))
        cr_return_types = { i64: 'Int64', f64: 'Float64' }

        write class_method ? "def self.#{crystal_name}" : "def #{crystal_name}"
        emit_param_list(method, param_types: param_types)
        write " : String" if string_return
        write " : Bool" if bool_return && !string_return
        write " : #{cr_return_types[raw_return]}" if raw_return && !bool_return
        emit_newline

        if bool_return
          indented do
            write "(begin"
            emit_newline
            indented { emit(method.body) }
            emit_newline
            emit_indent
            write "end).truthy?"
          end
        elsif string_return
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
          # Emit Crystal tuple return when method is called in masgn context
          @mctx.emit_crystal_tuple = @masgn_return_methods&.include?(name)
          indented { emit(method.body) }
          @mctx.emit_crystal_tuple = false
        end

        emit_newline
        emit_indent
        write "end"
      ensure
        @mctx = old_mctx
      end

      # -----------------------------------------------------------------------
      # Emit settled non-class constants
      # -----------------------------------------------------------------------

      # Serialize settled global variable values from the load phase.
      # Only emit user-defined globals (those with simple alphanumeric names).
      def emit_global_initializers(globals)
        globals.each do |name, value|
          key = name.to_s.sub(/^\$/, '')
          # Only emit globals with safe alphanumeric+underscore names (skip $", $,, $stdout, etc.)
          next unless key.match?(/\A[a-zA-Z_]\w*\z/)
          # Skip well-known internal globals
          next if %w[stdout stderr stdin LOAD_PATH LOADED_FEATURES VERBOSE DEBUG PROGRAM_NAME SAFE].include?(key)
          crystal_val = vm_value_to_crystal(value)
          next unless crystal_val
          line "RUBY_GLOBALS[\"#{key}\"] = #{crystal_val}"
        end
        emit_newline
      end

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
          # Large byte arrays: emit compact Bytes literal + map
          if value.raw.size > 256 && value.raw.all? { |e| e.is_a?(Vm::IntegerObject) && e.raw >= 0 && e.raw <= 255 }
            bytes = value.raw.map { |e| e.raw.to_s }.join(', ')
            return "RubyArray.new(Bytes[#{bytes}].to_a.map { |b| RubyInteger.new(b.to_i64).as(RubyObject) })"
          end
          return nil if value.raw.size > 1000  # Skip very large non-byte arrays
          elems = value.raw.map { |e| vm_value_to_crystal(e) }
          return nil if elems.any?(&:nil?)
          "RubyArray.new([#{elems.join(', ')}] of RubyObject)"
        else                        nil
        end
      end

      # -----------------------------------------------------------------------
      # Type inference — call-site analysis from execute block
      # -----------------------------------------------------------------------

      def run_type_inference(execute_block, top_level_scope)

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

        # Delegate all type-to-Crystal mapping to CrystalTypeMapper
        mapper = CrystalTypeMapper.new(env,
          user_methods: user_methods_hash,
          user_classes: user_classes_hash,
          opt_flags: @opt_flags
        ).build!

        @ti_user_class_names         = mapper.user_class_names
        @ti_local_types              = mapper.local_types
        @ti_locals                   = mapper.locals
        @ti_arrays                   = mapper.arrays
        @ti_class_locals             = mapper.class_locals
        @ti_local_array_elems        = mapper.local_array_elems
        @ti_block_params             = mapper.block_params
        @ti_class_params             = mapper.class_params
        @inferred_params             = mapper.inferred_params
        @typed_params                = mapper.typed_params
        @typed_method_returns        = mapper.typed_method_returns
        @instance_method_raw_returns = mapper.instance_method_raw_returns
        @const_raw_types             = mapper.const_raw_types
        @typed_ivars                 = mapper.typed_ivars
      end

      # Is this a complex Crystal-native type that callers may not be able to provide?
      # Simple natives (Int64, Float64, Array(Int64)) are fine — callers construct them locally.
      # Complex natives (Array(Array(Int64))) need genericising in fallback overloads.
      def param_name?(name) = @mctx.param_set&.include?(name)

      # Can this expression be passed as a raw Int64/Float64 arg?
      # Typed locals and arithmetic expressions of raw operands — yes.
      # Bare literals — no (target might not have raw overload).
      def raw_passable_arg?(node)
        return false unless node_raw_type(node)
        case node
        when Ast::LocalVariableRead then true
        when Ast::MethodCall
          # Arithmetic/bitwise on raw operands: ba ^ bb, a + b, etc.
          ARITH_OPS_UNBOX.include?(node.name) && node.receiver_node && node_raw_type(node.receiver_node)
        else false
        end
      end

      def complex_native_type?(t)
        CrystalType.array?(t) && CrystalType.array?(CrystalType.elem(t))
      end

      def returns_array_literal?(body) = last_body_expression(body).is_a?(Ast::ArrayLiteral)

      # Collect method names called as RHS of multiple assignment (candidates for Crystal tuple return).
      def collect_masgn_return_methods(body, scope)
        result = Set.new
        collect_masgn_rhs = ->(node) {
          return unless node
          case node
          when Ast::MultipleAssignment
            rhs = node.instance_variable_get(:@value_node)
            if rhs.is_a?(Ast::MethodCall) && rhs.instance_variable_get(:@receiver_node).nil?
              mname = rhs.instance_variable_get(:@name)
              method = scope.instance_variable_get(:@methods_table)&.fetch(mname, nil)
              result << mname if method.is_a?(Vm::Method) && returns_array_literal?(method.body)
            end
          when Ast::Sequence
            node.nodes.each { |n| collect_masgn_rhs.call(n) }
          when Ast::If
            collect_masgn_rhs.call(node.instance_variable_get(:@then_node))
            collect_masgn_rhs.call(node.instance_variable_get(:@else_node))
          when Ast::While, Ast::Until
            collect_masgn_rhs.call(node.instance_variable_get(:@body_node))
          when Ast::MethodCall
            blk = node.instance_variable_get(:@block_node)
            collect_masgn_rhs.call(blk.instance_variable_get(:@body)) if blk.respond_to?(:body)
          end
        }
        # Scan execute block
        collect_masgn_rhs.call(body)
        # Scan user method bodies
        (scope.instance_variable_get(:@methods_table) || {}).each_value do |m|
          collect_masgn_rhs.call(m.body) if m.is_a?(Vm::Method)
        end
        result
      end

      def last_body_expression(node)
        case node
        when Ast::Sequence then node.nodes.last ? last_body_expression(node.nodes.last) : nil
        else node
        end
      end

      # Combined element type for typed-array and native-array locals.

      # Override emit_param_list to apply inferred types for required params.
      def emit_param_list(node, param_types: nil)
        return super(node) unless param_types

        parts  = []
        req    = ivar(node, :required_params) || []
        types  = param_types + [:ruby_object] * [req.size - param_types.size, 0].max

        req.each_with_index do |p, i|
          parts << "#{crystal_local(p)} : #{CrystalType.to_crystal(types[i] || :ruby_object)}"
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

      # Map a class name symbol to the Crystal class name.
      # Uses RUBY_TO_CRYSTAL_TYPE for built-in classes, Ruby_ prefix for user classes.
      def crystal_class_name(cls)
        CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
      end

      # Override: for typed locals in boxed context, wrap in RubyInteger/RubyFloat.
      def emit_local_var_read(node)
        name = ivar(node, :name)
        case @mctx.typed_locals[name]
        when :i64 then write "RubyInteger.new(#{crystal_local(name)})"
        when :f64 then write "RubyFloat.new(#{crystal_local(name)})"
        else
          case @mctx.raw_block_params[name]
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
        # Nested array construction: c = Array.new(m) { Array.new(p, 0.0) }
        # Emit as Array(Array(Float64)).new(m) { Array(Float64).new(p, 0.0) }
        nat_elem = native_array_elem_type(name)
        if nat_elem && CrystalType.array?(nat_elem)
          inner_scalar = CrystalType.elem(nat_elem)
          inner_crystal = CrystalType.to_crystal(nat_elem)
          rhs  = ivar(node, :value_node)
          blk  = ivar(rhs, :block_node)
          outer_args = ivar(rhs, :arg_nodes) || []
          inner = ivar(blk, :body)
          inner = inner.nodes.first if inner.is_a?(Ast::Sequence) && inner.nodes.size == 1
          inner_args = ivar(inner, :arg_nodes) || []
          write "#{crystal_local(name)} = Array(#{inner_crystal}).new("
          emit_coerce_i64(outer_args[0])
          write ") { #{inner_crystal}.new("
          emit_coerce_i64(inner_args[0])
          write ", "
          emit_as(inner_args[1], inner_scalar)
          write ") }"
          return
        end
        if (arr_ty = @mctx.typed_array_locals[name])
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
        if (elem_ty = @mctx.local_array_elems[name]) && !@mctx.typed_array_locals.key?(name)
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
              @mctx.native_array_locals[name] = elem_ty
              return
            end
          end
        end
        if (raw_ty = @mctx.typed_locals[name])
          write "#{crystal_local(name)} = "
          emit_as(ivar(node, :value_node), raw_ty)
          return
        end
        if @mctx.local_array_elems.key?(name)
          # Check if RHS is a read from a nested native array: ci = c[i]
          value = ivar(node, :value_node)
          if value.is_a?(Ast::MethodCall) && ivar(value, :name) == :[] &&
             (vargs = ivar(value, :arg_nodes) || []).size == 1 &&
             ivar(value, :receiver_node).is_a?(Ast::LocalVariableRead)
            recv_elem = native_array_elem_type(ivar(ivar(value, :receiver_node), :name))
            if recv_elem && CrystalType.array?(recv_elem)
              # Emit: ci = c[raw_i]  (Crystal infers ci : Array(T))
              write "#{crystal_local(name)} = "
              emit(value)
              @mctx.native_array_locals[name] = @mctx.local_array_elems[name]
              return
            end
          end
          write "#{crystal_local(name)} = "
          old_suppress = @suppress_tuple_literals
          @suppress_tuple_literals = true  # local assignment — might be mutated later
          emit(ivar(node, :value_node))
          @suppress_tuple_literals = old_suppress
          write ".as(RubyArray)" unless ivar(node, :value_node).is_a?(Ast::ArrayLiteral)
          return
        end
        if (cls = @mctx.class_locals[name])
          write "#{crystal_local(name)} = "
          emit(ivar(node, :value_node))
          write ".as(#{crystal_class_name(cls)})"
          return
        end
        # Suppress tuple literals for plain local assignments — arrays may be mutated later
        old_suppress = @suppress_tuple_literals
        @suppress_tuple_literals = true
        super
        @suppress_tuple_literals = old_suppress
      end

      # Override: emit small fixed-size array literals as RubyTupleN (single
      # allocation, N inline fields) instead of RubyArray (3 allocations).
      # Exception: in return position, emit Crystal tuple {a, b} for zero-cost
      # multi-return that preserves per-element types.
      MAX_TUPLE_SIZE = 8

      def emit_array_literal(node)
        return super unless opt?(:tuple_literals) && !@suppress_tuple_literals
        elems = ivar(node, :element_nodes) || []
        if elems.size >= 1 && elems.size <= MAX_TUPLE_SIZE &&
           elems.none? { |e| e.is_a?(Ast::SplatArg) }
          if @mctx.emit_crystal_tuple
            # Return position: Crystal tuple preserves per-element types
            write "{"
            elems.each_with_index do |el, i|
              write ", " if i > 0
              emit(el)
            end
            write "}"
          else
            write "RubyTuple#{elems.size}.new("
            elems.each_with_index do |el, i|
              write ", " if i > 0
              emit(el)
            end
            write ")"
          end
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
                       @mctx.local_array_elems[ivar(recv_node, :name)]
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
          if CrystalType.scalar?(pt)
            # Coerce arg to raw type: use emit_raw if already typed,
            # otherwise emit and append .to_i64/.to_f64
            emit_as(arg, pt)
          else
            emit(arg)
          end
        end
        write ")"
      end

      def emit_method_call(node)
        # Constant-fold respond_to?(:literal) and is_a?/kind_of?(Constant) when
        # receiver type is known. In the closed world, method existence and class
        # hierarchy are fully determined at compile time.
        if node.receiver_node && (recv_class = receiver_known_class(node.receiver_node))
          klass = lookup_vm_class(recv_class)
          if klass
            # respond_to?(:symbol_literal) → RUBY_TRUE / RUBY_FALSE
            if node.name == :respond_to? &&
               node.arg_nodes&.size&.between?(1, 2) &&
               node.arg_nodes[0].is_a?(Ast::SymbolLiteral)
              method_name = ivar(node.arg_nodes[0], :value).raw
              write(klass.lookup_method(method_name) ? "RUBY_TRUE" : "RUBY_FALSE")
              return
            end

            # is_a?(ConstantLiteral) / kind_of?(ConstantLiteral) → RUBY_TRUE / RUBY_FALSE
            if (node.name == :is_a? || node.name == :kind_of?) &&
               node.arg_nodes&.size == 1 &&
               node.arg_nodes[0].is_a?(Ast::ConstantRead)
              target_name = ivar(node.arg_nodes[0], :name)
              target_class = lookup_vm_class(target_name)
              if target_class
                write(klass.ancestors_include?(target_class) ? "RUBY_TRUE" : "RUBY_FALSE")
                return
              end
            end
          end
        end

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
             params.all? { |p| p.is_a?(Symbol) && @mctx.block_params[p] == :i64 } &&
             args.size == 1 && node_raw_type(args[0]) == :i64
            write "RubyArray.new("
            emit_raw(args[0])
            write ") { |"
            write params.map { |p| crystal_local(p) }.join(", ")
            write "|"
            emit_newline
            old_rbp = @mctx.raw_block_params
            @mctx.raw_block_params = old_rbp.merge(params.map { |p| [p, :i64] }.to_h)
            indented { emit_native_block_body(ivar(blk, :body)) }
            @mctx.raw_block_params = old_rbp
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
          recv_class = @mctx.class_locals[recv_name]
          if recv_class && (tp = @ti_class_params[[recv_class, node.name]])
            emit(node.receiver_node)
            write ".#{crystal_method_name(node.name)}"
            emit_typed_call_args(node.arg_nodes || [], tp)
            return
          end
        end

        # Nested native array read: mc[i] where mc is Array(Array(T)) — coerce index, no boxing
        if node.name == :[] && node.receiver_node&.is_a?(Ast::LocalVariableRead) &&
           (recv_elem = native_array_elem_type(ivar(node.receiver_node, :name))) &&
           CrystalType.array?(recv_elem) && node.arg_nodes&.size == 1
          write "#{crystal_local(ivar(node.receiver_node, :name))}["
          emit_coerce_i64(node.arg_nodes[0])
          write "]"
          return
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
          # Only use raw Int64 index for known array/tuple receivers — user classes
          # may not have [](Int64) and need boxing to dispatch [](RubyObject).
          recv = node.receiver_node
          recv_is_array = recv.is_a?(Ast::LocalVariableRead) &&
            (@mctx.typed_array_locals[ivar(recv, :name)] ||
             @mctx.local_array_elems[ivar(recv, :name)] ||
             native_array_elem_type(ivar(recv, :name)))
          if recv_is_array || !recv.is_a?(Ast::LocalVariableRead)
            emit(node.receiver_node)
            write "["
            emit_raw(node.arg_nodes[0])
            write "]"
            return
          end
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

        # Free call inside class/module: dispatch to class method (self.x) if
        # the method exists on the eigenclass. Prevents module_function methods
        # from dispatching to the RubyObject *args stub.
        if node.receiver_node.nil? && @current_class_eigen_methods&.include?(node.name)
          write "self.#{crystal_method_name(node.name)}"
          if !@mctx.suppress_typed_call_args && (opt?(:call_site_types) || opt?(:method_specialization))
            tp = @inferred_params[node.name] || @ti_class_params[[@current_class_name, node.name]]
            can_use_typed = tp&.any? { |t| t && t != :ruby_object } &&
              tp.all? { |pt| !pt || CrystalType.generic_compatible?(pt) || CrystalType.scalar?(pt) }
            if can_use_typed
              emit_typed_call_args(node.arg_nodes || [], tp)
            else
              emit_call_args(node)
            end
          else
            emit_call_args(node)
          end
          return
        end

        # Free call to method with typed params — coerce args to declared types
        if !@mctx.suppress_typed_call_args && node.receiver_node.nil? && (tp = @inferred_params[node.name])
          write crystal_method_name(node.name)
          emit_typed_call_args(node.arg_nodes || [], tp)
          return
        end

        # Devirtualize: cast class-typed receiver locals so Crystal sees the
        # Devirtualize: cast class-typed receiver locals so Crystal sees the
        # concrete type and can inline/devirtualize the method call.
        if node.receiver_node.is_a?(Ast::LocalVariableRead)
          recv_name  = ivar(node.receiver_node, :name)
          recv_class = @mctx.class_locals[recv_name]
          if recv_class
            write "#{crystal_local(recv_name)}.as(#{crystal_class_name(recv_class)}).#{crystal_method_name(node.name)}"
            emit_call_args(node)
            return
          end
        end

        # Typed arithmetic/comparison: if BOTH operands are raw-typed, emit
        # raw Crystal arithmetic instead of going through RubyObject dispatch.
        # Requires both sides typed to avoid coercing unknown-type values.
        if node.receiver_node && (node.arg_nodes || []).size == 1 &&
           (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name)
          rt = node_raw_type(node.receiver_node)
          at = node_raw_type(node.arg_nodes[0])
          if rt && at
            ty = (rt == :f64 || at == :f64) ? :f64 : :i64
            if CrystalEmitter::COMPARE_OPS.include?(node.name)
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

      # Override: emit typed local args as raw in method calls.
      # Crystal's overload resolution picks Int64/Float64 overloads where
      # available, and *args stubs accept any type.
      def emit_call_args(node)
        return super unless opt?(:unbox_locals)
        return super if node.name == :new  # constructors may not have Int64 overloads
        args = node.arg_nodes
        kw_args = node.kw_arg_nodes
        return if args.empty? && kw_args.empty? && node.block_node.nil?

        # Pass typed local variables and raw arithmetic expressions as raw —
        # Crystal's overload resolution picks the Int64/Float64 overload when available.
        # Don't pass literals raw (they might reach functions expecting RubyObject).
        has_raw_arg = args.any? { |a| raw_passable_arg?(a) }
        return super unless has_raw_arg

        write "("
        first = true
        args.each do |arg|
          write ", " unless first
          first = false
          if arg.is_a?(Ast::SplatArg)
            write "# UNSUPPORTED_SPLAT("; emit(ivar(arg, :value_node)); write ")"
          elsif raw_passable_arg?(arg)
            emit_raw(arg)
          else
            emit(arg)
          end
        end
        kw_args.each do |kw_name, val_node|
          write ", " unless first
          first = false
          key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
          write "#{key}: "
          emit(val_node)
        end
        write ")"

        if node.block_node
          write " "
          if node.block_node.is_a?(Ast::BlockArg)
            emit_block_arg(node.block_node)
          else
            emit_block(node.block_node)
          end
        end
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
             (elem_ty = @mctx.local_array_elems[ivar(recv, :name)]) &&
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
          if rt && at
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

        # Typed multi-return: RHS is a call to a user method that returns a Crystal tuple.
        # Destructure directly without masgn_coerce.
        has_splat = targets.any? { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if !has_splat && rhs.is_a?(Ast::MethodCall) && ivar(rhs, :receiver_node).nil?
          method_name = ivar(rhs, :name)
          method = @top_level_scope.instance_variable_get(:@methods_table)&.fetch(method_name, nil)
          if method.is_a?(Vm::Method) && returns_array_literal?(method.body)
            # Emit: _t0, _t1 = func(args)
            tmp_names = targets.each_with_index.map { |_, i| "_tup#{@temp_counter}_#{i}" }
            @temp_counter += 1
            write tmp_names.join(", ")
            write " = "
            emit(rhs)
            targets.each_with_index do |t, i|
              emit_newline; emit_indent
              emit_masgn_assign(t, tmp_names[i])
            end
            return
          end
        end

        # Fast path: no splat, all targets are typed locals, RHS is ArrayLiteral
        if !has_splat && rhs.is_a?(Ast::ArrayLiteral)
          elems = ivar(rhs, :element_nodes) || []
          all_typed = targets.all? do |t|
            t[0] == :local && (
              @mctx.typed_locals[t[1]] ||
              @mctx.typed_array_locals[t[1]] ||
              @mctx.class_locals[t[1]]
            )
          end
          if all_typed && elems.size >= targets.size
            targets.each_with_index do |t, i|
              emit_newline unless i == 0
              emit_indent unless i == 0
              name   = t[1]
              elem   = elems[i]
              if (raw_ty = @mctx.typed_locals[name])
                write "#{crystal_local(name)} = "
                emit_as(elem, raw_ty)
              elsif (cls = @mctx.class_locals[name])
                write "#{crystal_local(name)} = "
                emit(elem)
                write ".as(#{crystal_class_name(cls)})"
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
              (ty = @mctx.typed_locals[target[1]])
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
              crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
              ret_type = kind == :class_or_nil ? "#{crystal_cls} | RubyNil" : crystal_cls
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
