require_relative 'crystal_emitter'
require_relative 'crystal_type_mapper'
require_relative 'type_inference'
require_relative 'method_context'
require_relative 'class_context'
require_relative 'global_context'
require_relative 'compile_context'
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
        @cc = CompileContext.new(top_level_scope: top_level_scope, stub_file: stub_file)
        @mctx = MethodContext.new
        @cctx = ClassContext.new
        @gctx = GlobalContext.new

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

        # Whole-program type inference (replaces all ad-hoc pre-passes)
        run_type_inference(execute_block, top_level_scope)

        # Pre-scan: find methods on Object that will get real instance method
        # implementations on RubyObject (so we skip *args stubs for them).
        top_level_scope.methods_table&.each do |name, m|
          @cc.object_instance_methods << name if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end

        emit_header
        emit_bench_harness_require if bench_stub?
        emit_user_method_stubs unless @cc.user_methods.empty?

        # Collect class-typed ivars (X | nil patterns) across all methods
        collect_class_typed_ivars(top_level_scope) if opt?(:ivar_narrowing)

        # Scan for methods called in masgn RHS (multi-return → Crystal tuple)
        @cc.masgn_return_methods = collect_masgn_return_methods(execute_block&.body, top_level_scope)

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
          @mctx.typed_locals = opt?(:unbox_locals) ? (@gctx.locals[nil] || {}) : {}
          @mctx.typed_array_locals = opt?(:native_arrays) ? (@gctx.arrays[nil] || {}) : {}
          @mctx.class_locals = opt?(:devirtualize) ? (@gctx.class_locals[nil] || {}) : {}
          @mctx.local_array_elems = opt?(:native_arrays) ? (@gctx.local_array_elems[nil] || {}) : {}
          @mctx.block_params = @gctx.block_params[nil] || {}
          @mctx.local_types = @gctx.local_types[nil] || {}
          @mctx.method_body = execute_block.body
          @cc.in_execute_block = true
          emit_indent
          emit(execute_block.body)
          emit_newline
          @cc.in_execute_block = false
        end

        @out
      end

      private

      # -----------------------------------------------------------------------
      # Source-location filtering
      # -----------------------------------------------------------------------

      def bench_stub? = @cc.bench_stub?

      # Resolve a receiver AST node to a known class Symbol (from TI devirtualize).
      def receiver_known_class(recv)
        return nil unless recv.is_a?(Ast::LocalVariableRead)
        cls_entry = @mctx.class_locals[recv.name]
        cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
      end

      # Look up a VM class/module by name in the top-level constant table.
      def lookup_vm_class(name)
        val = @cc.top_level_scope.constants_table&.fetch(name, nil)
        val.is_a?(Vm::ModuleObject) ? val : nil
      end

      def user_source_location?(loc)
        return false if loc.nil?
        # source_location is "file:line" — strip the :line suffix for comparison
        file = loc.is_a?(Array) ? loc.first.to_s : loc.to_s.sub(/:[\d]+\z/, '')
        return false if @cc.stub_file && file == @cc.stub_file
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
        class_is_user = scope.constants_locations&.any? do |_, loc|
          user_source_location?(loc)
        end || (scope != Vm::Core::OBJECT_CLASS &&
                scope.methods_table&.any? do |_, m|
                  m.is_a?(Vm::Method) && user_source_location?(m.source_location)
                end)

        scope.methods_table&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          if user_source_location?(method.source_location)
            @cc.user_methods << name
          elsif class_is_user && accessor_method?(method)
            @cc.user_methods << name
          end
        end

        scope.constants_table&.each do |_name, value|
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

        const_locs = scope.constants_locations || {}
        scope.constants_table&.each do |name, value|
          next unless value.is_a?(Vm::ModuleObject)
          next if SKIP_CONSTANTS.include?(name)
          emit_user_class(name, value, const_loc: const_locs[name])
          emit_user_classes(value, visited)
        end
      end

      def emit_user_class(name, mod, const_loc: nil)
        user_methods = collect_class_user_methods(mod)
        return unless user_methods.any? { |_, m| user_source_location?(m.source_location) } ||
                      user_source_location?(const_loc)

        emit_class_header(name, mod)
        old_cctx = @cctx
        @cctx = ClassContext.new
        @cctx.name = name
        @cctx.ivars = @gctx.typed_ivars.fetch(name, {})
        @cctx.typed_ivars = @gctx.class_typed_ivars.fetch(name, {})

        indented do
          emit_ivar_declarations(user_methods)
          emit_default_stringifiers(name, user_methods)
          emit_user_constants(mod)
          emit_newline
          eigen_names = collect_eigen_method_names(mod)
          emit_instance_methods(name, user_methods, eigen_names)
          emit_class_methods(name, mod, eigen_names)
          emit_respond_to(mod) if mod.is_a?(Vm::ClassObject)
        end

        @cctx = old_cctx
        @cctx.eigen_methods = nil
        emit_indent
        write "end"
        emit_newline
      end

      def collect_class_user_methods(mod)
        is_struct = mod.is_a?(Vm::ClassObject) && struct_subclass?(mod)
        methods = mod.methods_table&.select do |_n, m|
          m.is_a?(Vm::Method) &&
            (user_source_location?(m.source_location) || accessor_method?(m) ||
             (is_struct && _n == :initialize))
        end
        methods || {}
      end

      def emit_class_header(name, mod)
        is_class = mod.is_a?(Vm::ClassObject)
        kw = is_class ? "class" : "module"
        sc_name = is_class ? mod.superclass&.name : nil
        write "#{kw} Ruby_#{crystal_constant(name)}"
        if sc_name && !%i[Object BasicObject Struct Data].include?(sc_name)
          write " < Ruby_#{crystal_constant(sc_name)}"
        elsif is_class
          write " < RubyObject"
        end
        emit_newline
      end

      def emit_ivar_declarations(user_methods)
        all_ivars = user_methods.each_with_object([]) do |(_, m), acc|
          acc.concat(collect_ivars(m.body)) if m.body
        end.uniq
        all_ivars.each do |iv|
          type_ann, default = ivar_type_annotation(iv.to_sym)
          emit_indent
          line "#{iv} : #{type_ann} = #{default}"
        end
        emit_newline unless all_ivars.empty?
      end

      def ivar_type_annotation(iv_sym)
        case @cctx.ivars[iv_sym]
        when Type::F64 then ["Float64", "0.0_f64"]
        when Type::I64 then ["Int64", "0_i64"]
        when Type::ARRAY_F64 then ["Array(Float64)", "Array(Float64).new"]
        when Type::ARRAY_I64 then ["Array(Int64)", "Array(Int64).new"]
        else
          ct = @cctx.typed_ivars[iv_sym]
          return ["RubyObject", "RUBY_NIL"] unless ct
          kind, cls = ct
          crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
          # Crystal nilable only for self-referential tree links (e.g. Node @left : Node?)
          # Other class_or_nil ivars stay as RubyObject (they store heterogeneous values)
          return ["#{crystal_cls}?", "nil"] if kind == :class_or_nil && cls == @cctx.name
          default = { Array: "RubyArray.new", Hash: "RubyHash.new", String: "RubyString.new" }[cls]
          default ? [crystal_cls, default] : ["#{crystal_cls} | RubyNil", "RUBY_NIL"]
        end
      end

      def emit_default_stringifiers(name, user_methods)
        emit_indent; line "def to_s : String; \"#<#{name}>\"; end" unless user_methods.key?(:to_s)
        emit_indent; line "def inspect : String; \"#<#{name}>\"; end" unless user_methods.key?(:inspect)
      end

      def collect_eigen_method_names(mod)
        eigenclass = mod.eigenclass or return Set.new
        (eigenclass.methods_table || {}).select { |_, m|
          m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        }.keys.to_set
      end

      def emit_instance_methods(class_name, user_methods, eigen_names)
        @cctx.eigen_methods = nil
        user_methods.each do |mname, method|
          next if eigen_names.include?(mname) && mname != :initialize
          emit_indent
          if accessor_method?(method)
            emit_accessor_method(mname, method)
          else
            emit_instance_method_overloads(class_name, mname, method)
          end
        end
      end

      def emit_instance_method_overloads(class_name, mname, method)
        inst_param_types = @gctx.class_params[[class_name, mname]]
        has_typed = inst_param_types&.any? { |t| t && !t.bottom? }
        if has_typed
          emit_vm_method(mname, method, param_types: inst_param_types)
          emit_newline; emit_newline; emit_indent
          emit_vm_method(mname, method)
        else
          emit_vm_method(mname, method, param_types: inst_param_types)
        end
        emit_newline; emit_newline
      end

      def emit_class_methods(class_name, mod, eigen_names)
        @cctx.eigen_methods = eigen_names
        eigenclass = mod.eigenclass or return
        class_methods = eigenclass.methods_table&.select { |_, m|
          m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        } || {}
        class_methods.each do |mname, method|
          emit_class_method_overloads(class_name, mname, method)
        end
      end

      def emit_class_method_overloads(class_name, mname, method)
        class_param_types = @gctx.class_params[[class_name, mname]] || @gctx.inferred_params[mname]
        raw_types = class_param_types&.map { |t| t.raw? ? t : nil }
        if opt?(:method_specialization) && raw_types&.any?
          class_return = @gctx.instance_method_raw_returns[[class_name, mname]]
          emit_indent
          emit_specialized_class_method(class_name, mname, method, raw_types, class_return, crystal_param_types: class_param_types)
          emit_newline; emit_newline
        end
        emit_indent
        generic_params = raw_types&.any? ? nil : class_param_types
        emit_vm_method(mname, method, param_types: generic_params, class_method: true)
        emit_newline; emit_newline
      end

      # Emit respond_to? as a closed-world method-presence lookup.
      # Walks the class's ancestor chain to collect all method names.
      # Collect ALL method names across ALL user classes and assign indices.
      # Index 0 is the sentinel (always-false for unknown method names).
      def build_method_index(scope)
        # Only build the method index if there are user-defined classes
        # that will emit respond_to? tables. Skip for programs with only
        # top-level methods — saves 900+ lines of symbol interning.
        has_user_classes = (scope.constants_table || {}).any? do |name, val|
          next unless val.is_a?(Vm::ClassObject)
          const_loc = scope.constants_locations&.dig(name)
          (user_source_location?(const_loc) ||
           val.methods_table&.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) }) &&
            !%i[Object BasicObject Kernel].include?(name)
        end
        @cc.method_index = { '__sentinel__' => 0 }
        return unless has_user_classes

        all_method_names = Set.new
        collect_all_method_names = ->(klass) {
          c = klass
          while c && c.is_a?(Vm::ClassObject)
            (c.methods_table || {}).each_key { |m| all_method_names << m }
            c.modules.each do |mod|
              (mod.methods_table || {}).each_key { |m| all_method_names << m }
            end
            c = c.superclass
          end
        }
        (scope.constants_table || {}).each_value do |val|
          collect_all_method_names.call(val) if val.is_a?(Vm::ClassObject)
        end
        collect_all_method_names.call(scope) if scope.is_a?(Vm::ClassObject)

        all_method_names.delete(:initialize)
        sorted = all_method_names.map(&:to_s).sort
        sorted.each_with_index { |name, i| @cc.method_index[name] = i + 1 }
      end

      def emit_method_index_table
        return if @cc.method_index.size <= 1 # only sentinel
        line "# Pre-intern method-name symbols with compile-time indices for O(1) respond_to?"
        @cc.method_index.each do |name, idx|
          next if name == '__sentinel__'
          line "RubySymbol.from(#{name.inspect}).method_index = #{idx}"
        end
        emit_newline
      end

      def emit_respond_to(klass)
        all_methods = Set.new
        c = klass
        while c && c.is_a?(Vm::ClassObject)
          (c.methods_table || {}).each_key { |m| all_methods << m }
          c.modules.each do |mod|
            (mod.methods_table || {}).each_key { |m| all_methods << m }
          end
          c = c.superclass
        end
        all_methods.delete(:initialize)

        # Build bit array: index 0 (sentinel) is always false
        table_size = @cc.method_index.size
        bits = Array.new(table_size, false)
        all_methods.each do |m|
          idx = @cc.method_index[m.to_s]
          bits[idx] = true if idx
        end

        emit_indent
        line "  RESPOND_TO_TABLE = StaticArray[#{bits.map { |b| b.to_s }.join(', ')}]"
        emit_newline

        emit_indent
        line "def respond_to?(name : RubyObject, _include_all : RubyObject = RUBY_FALSE) : RubyBool"
        indented do
          emit_indent
          write "sym = name.is_a?(RubySymbol) ? name : RubySymbol.from(name.to_s)"
          emit_newline
          emit_indent
          write "idx = sym.method_index"
          emit_newline
          emit_indent
          write "(idx > 0 && RESPOND_TO_TABLE[idx]) ? RUBY_TRUE : RUBY_FALSE"
        end
        emit_newline
        emit_indent
        line "end"
        emit_newline
      end

      # Override: skip *args stubs for methods that get real implementations
      # on RubyObject (user methods defined on Object).
      def emit_user_method_stubs
        stubs = @cc.user_methods.reject { |n|
          self.class.const_get(:RUBY_OBJECT_METHODS).include?(n) ||
            operator?(n) || @cc.object_instance_methods.include?(n)
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
        scope.methods_table&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)
          user_methods_on_object << [name, method]

          if opt?(:method_specialization) && @gctx.typed_params[name] && @gctx.typed_method_returns[name]
            emit_indent
            emit_specialized_vm_method(name, method)
            emit_newline
            emit_newline
          end

          # Emit typed overload when inferred params have complex types (Array, etc.)
          # that need a separate generic fallback for untyped callers.
          inferred = @gctx.inferred_params[name]
          has_complex_params = !@gctx.typed_params[name] && inferred&.any? { |t| complex_native_type?(t) }
          if has_complex_params
            emit_indent
            emit_vm_method(name, method, param_types: inferred)
            emit_newline
            emit_newline
          end

          # Always emit the generic overload — the execute block and other
          # untyped callers need it even when typed overloads exist.
          all_native = inferred&.all? { |t| t && t.native? }
          if all_native && !has_complex_params && !(@gctx.typed_params[name] && @gctx.typed_method_returns[name])
            emit_indent
            emit_vm_method(name, method, param_types: inferred)
            emit_newline
            emit_newline
          end
          emit_indent
          generic_params = if has_complex_params
            inferred.map { |t| t.native? ? Type::BOTTOM : t }
          elsif @gctx.typed_params[name]
            nil  # fully-typed → generic uses all RubyObject
          elsif all_native
            nil  # all-native typed overload handles raw; generic uses all RubyObject
          else
            # Drop raw scalar types to RubyObject, keep class types for devirtualization
            inferred&.map { |t| t.raw? ? Type::BOTTOM : t }
          end
          emit_vm_method(name, method, param_types: generic_params)
          emit_newline
          emit_newline
        end

        # Also emit as instance methods on RubyObject so receiver-based calls
        # (e.g., obj.should) dispatch correctly via Crystal's virtual dispatch.
        # This mirrors Ruby where Object methods are available both ways.
        # Track these so we skip generating *args stubs for them.
        @cc.object_instance_methods = user_methods_on_object.map(&:first).to_set
        return if user_methods_on_object.empty?
        # Filter out methods where all params are native — no generic needed
        generic_methods = user_methods_on_object.reject do |name, _|
          inferred = @gctx.inferred_params[name]
          inferred&.all? { |t| t && t.native? }
        end
        return if generic_methods.empty?
        line "# User methods on Object — also available as instance methods"
        line "class RubyObject"
        generic_methods.each do |name, method|
          emit_indent
          write "  "
          # Always use all-RubyObject for the Object instance method copy
          generic_params = nil
          emit_vm_method(name, method, param_types: generic_params)
          emit_newline
        end
        line "end"
        emit_newline
      end

      # Emit a Crystal method definition from a Vm::Method object.
      # Vm::Method has the same accessor names as Ast::MethodDef, so we can pass
      # it directly to emit_param_list.
      def emit_vm_method(name, method, param_types: nil, class_method: false)
        old_mctx = @mctx
        @mctx = MethodContext.new
        mkey = @cctx.name ? [@cctx.name, name] : name
        setup_method_context(name, method, mkey, param_types, class_method)

        string_return = STRING_RETURN_METHODS.include?(name)
        bool_return = %i[== != < <= > >= equal?].include?(name) && !class_method
        raw_return = compute_raw_return(name, param_types, class_method)
        crystal_name = string_return ? name.to_s : crystal_method_name(name)

        write class_method ? "def self.#{crystal_name}" : "def #{crystal_name}"
        emit_param_list(method, param_types: param_types)
        write " : String" if string_return
        write " : Bool" if bool_return && !string_return
        write " : #{raw_return.to_crystal}" if raw_return && !bool_return
        emit_newline
        emit_vm_method_body(method.body, name, bool_return: bool_return,
                            string_return: string_return, raw_return: raw_return)
        emit_newline; emit_indent; write "end"
      ensure
        @mctx = old_mctx
      end

      # -- emit_vm_method helpers -----------------------------------------------

      def has_specialized_overload?(name, class_method)
        class_method && @cctx.eigen_methods&.any? &&
          (@gctx.inferred_params[name] || @gctx.class_params[[@cctx.name, name]])&.any? { |t| !t.bottom? }
      end

      def setup_method_context(name, method, mkey, param_types, class_method)
        param_set = all_param_names(method).to_set
        @mctx.param_set = param_set
        generic_suppressed = has_specialized_overload?(name, class_method) && param_types.nil?
        @mctx.suppress_typed_call_args = generic_suppressed
        seed_ti_locals(mkey, param_set, generic_suppressed, param_types)
        @mctx.method_body = method.body
        @mctx.block_param_name = method.block_param
        @mctx.native_array_locals = {}
        seed_native_arrays(method.body, param_set)
        seed_param_types(method, param_types)
        seed_nested_array_locals(method.body, param_set)
        seed_literal_types(name, method.body, param_set, param_types, class_method)
      end

      def all_param_names(method)
        (method.required_params || []) +
          (method.optional_params || []).map(&:first) +
          [method.rest_param].compact +
          (method.post_params || [])
      end

      def seed_ti_locals(mkey, param_set, generic_suppressed, param_types)
        @mctx.typed_locals = (!generic_suppressed && opt?(:unbox_locals)) ? ((@gctx.locals[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.typed_array_locals = opt?(:native_arrays) ? ((@gctx.arrays[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.class_locals = opt?(:devirtualize) ? ((@gctx.class_locals[mkey] || {}).reject { |k, _| !param_types && param_set.include?(k) }) : {}
        @mctx.local_array_elems = opt?(:native_arrays) ? ((@gctx.local_array_elems[mkey] || {}).reject { |k, _| param_set.include?(k) }) : {}
        @mctx.block_params = (@gctx.block_params[mkey] || {}).reject { |k, _| param_set.include?(k) }
        @mctx.local_types = (@gctx.local_types[mkey] || {}).reject { |k, _| param_set.include?(k) }
      end

      def seed_native_arrays(body, param_set)
        return unless opt?(:native_arrays)
        detect_nested_array_locals(body, param_set).each do |lname, inner_elem|
          @mctx.native_array_locals[lname] = inner_elem.is_a?(Type) ? (inner_elem.i64? ? Type::ARRAY_I64 : Type::ARRAY_F64) : [:array, inner_elem]
        end
      end

      def seed_param_types(method, param_types)
        return unless param_types
        (method.required_params || []).each_with_index do |p, i|
          pt = param_types[i] or next
          if pt.raw? then @mctx.typed_locals[p] = pt
          elsif pt.array? || pt.array_scalar? then @mctx.native_array_locals[p] = pt.elem if pt.elem&.native?
          elsif pt.class_type? && !pt.bottom? then @mctx.class_locals[p] = pt.class_name
          end
        end
      end

      def seed_nested_array_locals(body, param_set)
        return unless opt?(:native_arrays)
        @mctx.local_types.each do |lname, ty|
          next if @mctx.native_array_locals.key?(lname) || param_set.include?(lname)
          next unless (ty.array? || ty.array_scalar?) && (ty.elem&.array? || ty.elem&.array_scalar?)
          @mctx.native_array_locals[lname] = ty.elem
        end
        return unless @mctx.local_array_elems.any?
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(body, assignments)
        @mctx.local_array_elems.each do |lname, elem_ty|
          next if @mctx.native_array_locals.key?(lname)
          (assignments[lname] || []).each do |rhs|
            next unless rhs.is_a?(Ast::MethodCall) && rhs.name == :[] &&
                        rhs.receiver_node.is_a?(Ast::LocalVariableRead)
            if @mctx.native_array_locals[rhs.receiver_node.name]&.array_scalar?
              @mctx.native_array_locals[lname] = elem_ty
              break
            end
          end
        end
      end

      def seed_literal_types(name, body, param_set, param_types, class_method)
        return if has_specialized_overload?(name, class_method) && param_types.nil?
        infer_local_types(body).each do |lname, ty|
          @mctx.typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
      end

      def compute_raw_return(name, param_types, class_method)
        return if has_specialized_overload?(name, class_method)
        return unless param_types&.any?(&:raw?) && opt?(:raw_returns) && !@gctx.typed_params[name]
        @gctx.typed_method_returns[name] ||
          (@cctx.name && @gctx.instance_method_raw_returns[[@cctx.name, name]])
      end

      def emit_vm_method_body(body, name, bool_return:, string_return:, raw_return:)
        if bool_return
          indented do
            write "((begin"; emit_newline
            indented { emit(body) }
            emit_newline; emit_indent; write "end) || RUBY_NIL).truthy?"
          end
        elsif string_return
          indented do
            write "(begin"; emit_newline
            indented { emit(body) }
            emit_newline; emit_indent; write "end).to_s"
          end
        elsif raw_return
          indented { emit_raw_expr(body) }
        else
          @mctx.emit_crystal_tuple = @cc.masgn_return_methods&.include?(name)
          indented { emit(body) }
          @mctx.emit_crystal_tuple = false
        end
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
        const_table = scope.constants_table || {}
        const_locs = scope.constants_locations || {}

        const_table.each do |name, value|
          next if SKIP_CONSTANTS.include?(name)
          next if value.is_a?(Vm::ModuleObject)

          loc = const_locs[name]
          next unless user_source_location?(loc)

          crystal_val = vm_value_to_crystal(value, const_name: name)
          next unless crystal_val

          line "Ruby_#{crystal_constant(name)} = #{crystal_val}"
        end
      end

      # Serialize a simple VM value to a Crystal expression string.
      # Returns nil for values that cannot be serialised (IO, Proc, etc.).
      def vm_value_to_crystal(value, const_name: nil)
        case value
        when Vm::IntegerObject then "RubyInteger.new(#{value.raw}_i64)"
        when Vm::FloatObject then "RubyFloat.new(#{float_bits_expr(value.raw)})"
        when Vm::StringObject then "RubyString.new(#{value.raw.inspect})"
        when Vm::NilObject then "RUBY_NIL"
        when Vm::TrueObject then "RUBY_TRUE"
        when Vm::FalseObject then "RUBY_FALSE"
        when Vm::SymbolObject then "RubySymbol.new(#{value.raw.inspect})"
        when Vm::ArrayObject
          # Native Array(Int64) for constants confirmed by TI as all-integer
          if const_name && @gctx.const_raw_types[const_name] == Type::ARRAY_I64
            return "Bytes[#{value.raw.map { |e| e.raw.to_s }.join(', ')}].to_a.map(&.to_i64)"
          end
          # Large byte arrays: emit compact Bytes literal + map
          if value.raw.size > 256 && value.raw.all? { |e| e.is_a?(Vm::IntegerObject) && e.raw >= 0 && e.raw <= 255 }
            bytes = value.raw.map { |e| e.raw.to_s }.join(', ')
            return "RubyArray.new(Bytes[#{bytes}].to_a.map { |b| RubyInteger.new(b.to_i64).as(RubyObject) })"
          end
          return nil if value.raw.size > 1000  # Skip very large non-byte arrays
          elems = value.raw.map { |e| vm_value_to_crystal(e) }
          return nil if elems.any?(&:nil?)
          "RubyArray.new([#{elems.join(', ')}] of RubyObject)"
        when Vm::ObjectObject
          # User class instance: emit Ruby_ClassName.new(ivar_values...)
          klass = value.class_object
          return nil unless klass.is_a?(Vm::ClassObject)
          class_name = klass.name
          return nil unless class_name && !SKIP_CONSTANTS.include?(class_name)
          init = klass.methods_table&.fetch(:initialize, nil)
          return nil unless init.is_a?(Vm::Method)
          # Only handle no-arg constructors for now
          if (init.required_params || []).empty?
            "Ruby_#{crystal_constant(class_name)}.new"
          else
            nil  # Can't serialize constructor args
          end
        else nil
        end
      end

      # -----------------------------------------------------------------------
      # Type inference — call-site analysis from execute block
      # -----------------------------------------------------------------------

      def param_name?(name) = @mctx.param_set&.include?(name)
      def complex_native_type?(t) = (t.array? || t.array_scalar?) && (t.elem.array? || t.elem.array_scalar?)

      def returns_array_literal?(body) = last_body_expression(body).is_a?(Ast::ArrayLiteral)

      def run_type_inference(execute_block, top_level_scope)
        user_methods_hash = {}
        top_level_scope.methods_table&.each do |name, m|
          user_methods_hash[name] = m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end
        user_classes_hash = {}
        collect_user_classes_recursive(top_level_scope, user_classes_hash)
        @gctx.user_class_names = user_classes_hash.keys.to_set

        all_constants = top_level_scope.constants_table || {}
        ti = TypeInference.new(
          user_methods: user_methods_hash,
          user_classes: user_classes_hash,
          execute_block: execute_block,
          constants: all_constants.dup
        )
        env = ti.run

        # Delegate all type-to-Crystal mapping to CrystalTypeMapper
        mapper = CrystalTypeMapper.new(env,
          user_methods: user_methods_hash,
          user_classes: user_classes_hash,
          opt_flags: @opt_flags
        ).build!

        @gctx.load_from_mapper!(mapper)

        # Extract kwarg types from TI env
        env.each_typed do |slot, ty|
          next unless slot.is_a?(Array) && slot[0] == :kwparam
          mkey, kw_name = slot[1], slot[2]
          (@gctx.inferred_kw_params[mkey] ||= {})[kw_name] = ty unless ty.bottom?
        end
      end

      # Can this expression be passed as a raw Int64/Float64 arg?
      # Typed locals and arithmetic expressions of raw operands — yes.
      # Bare literals — no (target might not have raw overload).
      def raw_passable_arg?(node)
        return false unless node_raw_type(node)
        case node
        when Ast::LocalVariableRead then true
        when Ast::IntegerLiteral, Ast::FloatLiteral then true
        when Ast::ConstantRead
          @gctx.const_raw_types.key?(node.name)
        when Ast::MethodCall
          # Arithmetic/bitwise on raw operands: ba ^ bb, a + b, etc.
          ARITH_OPS_UNBOX.include?(node.name) && node.receiver_node && node_raw_type(node.receiver_node)
        else false
        end
      end

      # Collect method names called as RHS of multiple assignment (candidates for Crystal tuple return).
      def collect_masgn_return_methods(body, scope)
        result = Set.new
        collect_masgn_rhs = ->(node) {
          return unless node
          case node
          when Ast::MultipleAssignment
            rhs = node.value_node
            if rhs.is_a?(Ast::MethodCall) && rhs.receiver_node.nil?
              mname = rhs.name
              method = scope.methods_table&.fetch(mname, nil)
              result << mname if method.is_a?(Vm::Method) && returns_array_literal?(method.body)
            end
          when Ast::Sequence
            node.nodes.each { |n| collect_masgn_rhs.call(n) }
          when Ast::If
            collect_masgn_rhs.call(node.then_node)
            collect_masgn_rhs.call(node.else_node)
          when Ast::While, Ast::Until
            collect_masgn_rhs.call(node.body_node)
          when Ast::MethodCall
            blk = node.block_node
            collect_masgn_rhs.call(blk.body) if blk.respond_to?(:body)
          end
        }
        # Scan execute block
        collect_masgn_rhs.call(body)
        # Scan user method bodies
        (scope.methods_table || {}).each_value do |m|
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

      # Override: when condition_simplify is enabled, emit && / || as native Crystal
      # boolean operators instead of RubyObject truthy dispatch.
      def crystal_bool_emittable?(node)
        return false unless opt?(:condition_simplify)
        case node
        when Ast::And then crystal_bool_emittable?(node.left_node) && crystal_bool_emittable?(node.right_node)
        when Ast::Or then crystal_bool_emittable?(node.left_node) && crystal_bool_emittable?(node.right_node)
        when Ast::MethodCall
          if comparison_op_call?(node)
            node_raw_type(node.receiver_node) && node_raw_type(node.arg_nodes[0])
          else
            false
          end
        when Ast::TrueLiteral, Ast::FalseLiteral then true
        else false
        end
      end

      def emit_crystal_bool(node)
        case node
        when Ast::And
          write "("
          emit_crystal_bool(node.left_node)
          write " && "
          emit_crystal_bool(node.right_node)
          write ")"
        when Ast::Or
          write "("
          emit_crystal_bool(node.left_node)
          write " || "
          emit_crystal_bool(node.right_node)
          write ")"
        when Ast::MethodCall
          rt = node_raw_type(node.receiver_node)
          at = node_raw_type(node.arg_nodes[0])
          ty = (rt&.f64? || at&.f64?) ? Type::F64 : Type::I64
          # Wrap in parens to protect embedded assignment precedence
          needs_parens = recv_contains_assignment?(node.receiver_node)
          write "("
          write "(" if needs_parens
          emit_as(node.receiver_node, ty)
          write ")" if needs_parens
          write " #{node.name} "
          emit_as(node.arg_nodes[0], ty)
          write ")"
        when Ast::TrueLiteral then write "true"
        when Ast::FalseLiteral then write "false"
        end
      end

      def emit_and(node)
        return super unless crystal_bool_emittable?(node)
        emit_crystal_bool(node)
      end

      def emit_or(node)
        return super unless crystal_bool_emittable?(node)
        emit_crystal_bool(node)
      end

      # Override emit_param_list to apply inferred types for required params.
      def emit_param_list(node, param_types: nil)
        # Apply kwarg typing only when positional params are also typed —
        # the generic overload needs all-RubyObject for Crystal dispatch.
        mkey = @cctx.name ? [@cctx.name, node.name] : node.name
        kw_types = param_types ? (@gctx.inferred_kw_params[mkey] || {}) : {}
        return super(node) unless param_types

        parts = []
        req = node.required_params || []
        if param_types
          types = param_types + [Type::BOTTOM] * [req.size - param_types.size, 0].max
          req.each_with_index { |p, i| t = types[i]; parts << "#{crystal_local(p)} : #{t&.bottom? == false ? t.to_crystal : 'RubyObject'}" }
        else
          req.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        end

        node.optional_params.each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        rp = node.rest_param
        parts << "*#{crystal_local(rp)} : RubyObject" if rp
        node.post_params.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        req_kw = node.required_kw_params || []
        opt_kw = node.optional_kw_params || []
        kr = node.kw_rest_param
        if (!req_kw.empty? || !opt_kw.empty?) && !rp
          parts << "*"  # Crystal keyword-only separator
        end
        req_kw.each do |p|
          ct = kw_types[p]
          parts << "#{crystal_local(p)} : #{ct ? ct.to_crystal : 'RubyObject'}"
        end
        opt_kw.each do |p, default|
          ct = kw_types[p]
          if ct && ct.raw? && default
            # Emit raw default for scalar-typed kwargs
            raw_default = ct == :i64 ? "#{default.value.raw}_i64" : "#{default.value.raw}_f64"
            parts << "#{crystal_local(p)} : #{ct.to_crystal} = #{raw_default}"
          elsif ct
            parts << "#{crystal_local(p)} : #{ct.to_crystal} = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}"
          else
            parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}"
          end
        end
        parts << "**#{crystal_local(kr)}" if kr
        bp = node.block_param
        parts << "&#{crystal_local(bp)}" if bp
        write "(#{parts.join(', ')})" unless parts.empty?
      end

      # Map a class name symbol to the Crystal class name.
      # Uses RUBY_TO_CRYSTAL_TYPE for built-in classes, Ruby_ prefix for user classes.
      def crystal_class_name(cls) = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"

      # Override: for typed locals in boxed context, wrap in RubyInteger/RubyFloat.
      def emit_local_var_read(node)
        name = node.name
        case @mctx.typed_locals[name]
        when Type::I64 then write "RubyInteger.new(#{crystal_local(name)})"
        when Type::F64 then write "RubyFloat.new(#{crystal_local(name)})"
        else
          case @mctx.raw_block_params[name]
          when Type::I64 then write "RubyInteger.new(#{crystal_local(name)})"
          when Type::F64 then write "RubyFloat.new(#{crystal_local(name)})"
          else super
          end
        end
      end

      # Override: for typed locals, emit RHS as bare Crystal numeric.
      # For typed array locals, emit Array(T).new construction.
      # For class-typed locals, add .as(Ruby_ClassName) cast for static dispatch.
      def cr_local_var_write(node)
        name = node.name
        # try_* helpers write imperatively; capture and return non-empty.
        handled = capture {
          try_nested_array_write(node, name) || try_range_to_a_write(node, name) ||
            try_native_dup_write(node, name) || try_typed_array_write(node, name) ||
            try_boxed_array_promote(node, name) || try_scalar_write(node, name) ||
            try_native_array_alias(node, name) || try_boxed_array_write(node, name) ||
            try_class_cast_write(node, name)
        }
        return handled unless handled.empty?
        @mctx.typed_array_locals.delete(name)
        old_suppress = @mctx.suppress_tuple_literals
        @mctx.suppress_tuple_literals = true
        result = "#{crystal_local(name)} = #{cr(node.value_node)}"
        @mctx.suppress_tuple_literals = old_suppress
        result
      end

      def emit_local_var_write(node) = write cr_local_var_write(node)

      # (0..n).to_a where TI says the result is Array[:i64] → native Crystal range to_a.
      def try_range_to_a_write(node, name)
        # Check: TI says this local is a typed array
        elem = @mctx.local_array_elems[name] || @mctx.typed_array_locals[name]
        return unless elem&.is_a?(Type) && elem.raw?
        rhs = node.value_node
        return unless rhs.is_a?(Ast::MethodCall) && rhs.name == :to_a
        recv = rhs.receiver_node
        # Unwrap parens: (0..n).to_a → Sequence([RangeLiteral]).to_a
        recv = recv.nodes.first while recv.is_a?(Ast::Sequence) && recv.nodes.size == 1
        return unless recv.is_a?(Ast::RangeLiteral)
        begin_node = recv.begin_node
        end_node = recv.end_node
        exclusive = recv.exclusive
        crystal_ty = elem.to_crystal
        write crystal_local(name), " = ("
        emit_coerce_i64(begin_node)
        write exclusive ? "..." : ".."
        emit_coerce_i64(end_node)
        write ").to_a"
        @mctx.native_array_locals[name] = elem
        true
      end

      # Array.new(m) { Array.new(p, fill) } or Array.new(n) { [] } — nested native construction.
      def try_nested_array_write(node, name)
        nat_elem = native_array_elem_type(name)
        return unless nat_elem
        is_array = nat_elem.array_scalar?
        return unless is_array
        rhs = node.value_node
        blk = rhs.is_a?(Ast::MethodCall) ? rhs.block_node : nil
        return unless blk.is_a?(Ast::Block)
        inner = blk.body
        inner = inner.nodes.first if inner.is_a?(Ast::Sequence) && inner.nodes.size == 1
        inner_crystal = nat_elem.to_crystal
        elem_of_nat = nat_elem.elem
        outer_args = rhs.arg_nodes || []
        if array_new_call?(inner)
          inner_args = inner.arg_nodes || []
          write crystal_local(name), " = Array(", inner_crystal, ").new("
          emit_coerce_i64(outer_args[0])
          write ") { ", inner_crystal, ".new("
          emit_coerce_i64(inner_args[0])
          write ", "; emit_as(inner_args[1], elem_of_nat); write ") }"
        elsif inner.is_a?(Ast::ArrayLiteral) && (inner.element_nodes || []).empty?
          write crystal_local(name), " = Array(", inner_crystal, ").new("
          emit_coerce_i64(outer_args[0])
          write ") { ", inner_crystal, ".new }"
        end
      end

      # Array.new(n, fill) with TI-known element type → native Array(T) construction.
      def try_typed_array_write(node, name)
        arr_ty = @mctx.typed_array_locals[name] or return
        rhs = node.value_node
        return unless array_new_call?(rhs)
        args = rhs.arg_nodes || []
        crystal_ty = arr_ty.to_crystal
        write crystal_local(name), " = Array(", crystal_ty, ").new("
        emit_coerce_i64(args[0]); write ", "; emit_as(args[1], arr_ty); write ")"
      end

      # Promote boxed-array local to native Array(T) from Array.new(n, default).
      def try_boxed_array_promote(node, name)
        elem_ty = @mctx.local_array_elems[name] or return
        return if @mctx.typed_array_locals.key?(name)
        rhs = node.value_node
        return unless array_new_call?(rhs)
        args = rhs.arg_nodes || []
        return unless args.size == 2
        crystal_ty = elem_ty.to_crystal
        write crystal_local(name), " = Array(", crystal_ty, ").new("
        emit_coerce_i64(args[0]); write ", "; emit_as(args[1], elem_ty); write ")"
        @mctx.native_array_locals[name] = elem_ty
      end

      # s = native_array.dup → propagate native type
      def try_native_dup_write(node, name)
        elem = @mctx.local_array_elems[name] || @mctx.typed_array_locals[name]
        return unless elem&.is_a?(Type) && elem.raw?
        rhs = node.value_node
        return unless rhs.is_a?(Ast::MethodCall) && (rhs.name == :dup || rhs.name == :clone)
        recv = rhs.receiver_node
        return unless recv.is_a?(Ast::LocalVariableRead)
        recv_elem = native_array_elem_type(recv.name)
        return unless recv_elem
        write crystal_local(name), " = ", crystal_local(recv.name), ".dup"
        @mctx.native_array_locals[name] = elem
        true
      end

      # Typed scalar local → emit raw value.
      def try_scalar_write(node, name)
        raw_ty = @mctx.typed_locals[name] or return
        write crystal_local(name), " = "
        emit_as(node.value_node, raw_ty)
        true
      end

      # ci = c[i] where c is native nested array → emit bare, Crystal infers.
      def try_native_array_alias(node, name)
        return unless @mctx.local_array_elems.key?(name) && native_array_elem_type(name)
        write crystal_local(name), " = "
        emit(node.value_node)
        true
      end

      # Boxed array local with known elem type → cast to RubyArray.
      def try_boxed_array_write(node, name)
        return unless @mctx.local_array_elems.key?(name)
        write crystal_local(name), " = "
        old_suppress = @mctx.suppress_tuple_literals
        @mctx.suppress_tuple_literals = true
        emit(node.value_node)
        @mctx.suppress_tuple_literals = old_suppress
        write ".as(RubyArray)" unless node.value_node.is_a?(Ast::ArrayLiteral)
        true
      end

      # Class-typed local → devirtualize cast.
      def try_class_cast_write(node, name)
        cls_entry = @mctx.class_locals[name] or return
        @_declared_typed_locals ||= Set.new
        val = node.value_node
        write crystal_local(name)
        # Only annotate non-nullable class locals on first assignment from safe sources.
        # Nullable locals get reassigned from different types (if/else branches) — skip.
        nullable = cls_entry.is_a?(Array) && cls_entry[1] == :nullable
        if !nullable && !@_declared_typed_locals.include?(name) && safe_for_type_annotation?(val)
          @_declared_typed_locals << name
          cls = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
          write " : ", crystal_class_name(cls)
        end
        write " = "
        emit(val)
        true
      end

      def safe_for_type_annotation?(val)
        case val
        when Ast::MethodCall
          val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
        when Ast::LocalVariableRead
          @_declared_typed_locals&.include?(val.name)
        when Ast::InstanceVariableRead
          # Cross-class nilable ivars use RubyNil, not Crystal Nil — annotation would mismatch
          ct = @cctx&.typed_ivars&.dig(val.name)
          !(ct.is_a?(Array) && ct[0] == :class_or_nil && ct[1] != @cctx&.name)
        else
          false
        end
      end

      # Override: emit small fixed-size array literals as RubyTupleN (single
      # allocation, N inline fields) instead of RubyArray (3 allocations).
      # Exception: in return position, emit Crystal tuple {a, b} for zero-cost
      # multi-return that preserves per-element types.
      MAX_TUPLE_SIZE = 8

      def emit_array_literal(node)
        return super unless opt?(:tuple_literals) && !@mctx.suppress_tuple_literals
        elems = node.element_nodes || []
        if elems.size >= 1 && elems.size <= MAX_TUPLE_SIZE &&
           elems.none? { |e| e.is_a?(Ast::SplatArg) }
          if @mctx.emit_crystal_tuple
            # Return position: Crystal tuple preserves per-element types.
            # Emit raw values for typed locals to avoid boxing.
            write "{"
            elems.each_with_index do |el, i|
              write ", " if i > 0
              rt = node_raw_type(el)
              rt ? emit_raw(el) : emit(el)
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
        case @cctx.ivars[node.name]
        when Type::F64 then write "RubyFloat.new(#{node.name})"
        when Type::I64 then write "RubyInteger.new(#{node.name})"
        else super
        end
      end

      # Override: for typed ivars, coerce RHS to the raw type.
      def cr_ivar_write(node)
        iv_name = node.name
        if (ty = @cctx.ivars[iv_name])
          val = node.value_node
          # Array-typed ivars: @list = Array.new(n) → Array(Float64).new(n, 0.0)
          if (ty == Type::ARRAY_F64 || ty == Type::ARRAY_I64) && val.is_a?(Ast::MethodCall) &&
             val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
            crystal_ty = ty == Type::ARRAY_F64 ? "Float64" : "Int64"
            default = ty == Type::ARRAY_F64 ? "0.0" : "0"
            args = val.arg_nodes || []
            count = args.empty? ? "0" : coerce_i64(args[0])
            return "#{iv_name} = Array(#{crystal_ty}).new(#{count}, #{default})"
          end
          # Nil-safe coercion for sentinel params
          if val.is_a?(Ast::LocalVariableRead) && !@mctx.typed_locals[val.name] && !node_raw_type(val)
            default = ty.f64? ? "0.0_f64" : "0_i64"
            coerce = ty.f64? ? ".to_f64" : ".to_i64"
            return "#{iv_name} = ((_v = #{cr(val)}); _v.ruby_nil? ? #{default} : _v#{coerce})"
          end
          return "#{iv_name} = #{raw_as(val, ty)}"
        elsif @cctx.typed_ivars[iv_name]&.first == :class_or_nil
          val = node.value_node
          rhs = if val.is_a?(Ast::NilLiteral)
            ct = @cctx.typed_ivars[iv_name]
            ct[1] == @cctx.name ? "nil" : "RUBY_NIL"
          else
            cr(val)
          end
          return "#{iv_name} = #{rhs}"
        end
        super
      end

      def emit_ivar_write(node) = write cr_ivar_write(node)

      # Override: for index op-write (ci[j] += ...) with a raw-typed index,
      # emit the index temp as bare Int64 so the Int64 array overload is used.
      def emit_index_op_write(node)
        idx = node.index_arg_nodes&.first
        op = node.operator
        recv_node = node.receiver_node
        val_node = node.value_node
        # Native Array(T) receiver: emit arr[i] op= val directly, coercing index to Int64
        recv_name = recv_node.is_a?(Ast::LocalVariableRead) && recv_node.name
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
                       @mctx.local_array_elems[recv_node.name]
        if recv_elem_ty
          unbox = recv_elem_ty.f64? ? ".as(RubyFloat).to_f64" : ".as(RubyInteger).to_i64"
          box = recv_elem_ty.f64? ? "RubyFloat" : "RubyInteger"
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
          pt&.raw? ? emit_as(arg, pt) : emit(arg)
        end
        write ")"
      end

      # Emit a value guaranteed to be RubyObject — box raw Int64/Float64 locals.
      def emit_boxed(node)
        vt = node_raw_type(node)
        if vt&.i64?
          write "RubyInteger.new("; emit_raw(node); write ")"
        elsif vt&.f64?
          write "RubyFloat.new("; emit_raw(node); write ")"
        else
          emit(node)
        end
      end

      def emit_method_call(node)
        s = cr_method_call_optimized(node)
        s ? write(s) : super
      end

      def cr_method_call(node) = cr_method_call_optimized(node) || super

      # Functional dispatch: try each cr_try_* helper, return first non-nil String, else nil.
      def cr_method_call_optimized(node)
        cr_try_ivar_array_access(node) ||
          cr_try_constant_fold(node) ||
          cr_try_native_array_new(node) ||
          cr_try_native_iteration(node) ||
          cr_try_typed_instance_call(node) ||
          cr_try_native_array_method(node) ||
          cr_try_array_push(node) ||
          cr_try_native_array_read(node) ||
          cr_try_boxed_array_read(node) ||
          cr_try_raw_index_read(node) ||
          cr_try_specialized_free_call(node) ||
          cr_try_eigen_dispatch(node) ||
          cr_try_typed_free_call(node) ||
          cr_try_devirtualized_call(node) ||
          cr_try_raw_arithmetic(node)
      end

      # Block string after typed call args (emit_call_args handles blocks itself).
      def cr_block_if_present(node)
        blk = node.block_node
        return "" unless blk && !blk.is_a?(Ast::BlockArg)
        " #{capture { emit_block(blk) }}"
      end

      # @list.fetch(i) or @list[i] on native array ivar → box result for RubyObject context
      def cr_try_ivar_array_access(node)
        recv = node.receiver_node
        return nil unless recv.is_a?(Ast::InstanceVariableRead)
        iv_ty = @cctx&.ivars&.dig(recv.name)
        return nil unless iv_ty == Type::ARRAY_F64 || iv_ty == Type::ARRAY_I64
        args = node.arg_nodes || []
        return nil unless (node.name == :fetch || node.name == :[]) && args.size == 1
        box = iv_ty == Type::ARRAY_F64 ? "RubyFloat" : "RubyInteger"
        "#{box}.new(#{recv.name}[#{coerce_i64(args[0])}])"
      end

      # Constant-fold respond_to?(:literal) and is_a?/kind_of?(Constant) when
      # receiver type is known from TI devirtualization.
      def cr_try_constant_fold(node)
        return nil unless node.receiver_node && (recv_class = receiver_known_class(node.receiver_node))
        klass = lookup_vm_class(recv_class) or return nil
        if node.name == :respond_to? && node.arg_nodes&.size&.between?(1, 2) &&
           node.arg_nodes[0].is_a?(Ast::SymbolLiteral)
          klass.lookup_method(node.arg_nodes[0].value) ? "RUBY_TRUE" : "RUBY_FALSE"
        elsif (node.name == :is_a? || node.name == :kind_of?) &&
              node.arg_nodes&.size == 1 && node.arg_nodes[0].is_a?(Ast::ConstantRead)
          target = lookup_vm_class(node.arg_nodes[0].name) or return nil
          klass.ancestors_include?(target) ? "RUBY_TRUE" : "RUBY_FALSE"
        end
      end

      # Array.new(n) { |i| body } with all-integer block params → native Int64 iteration.
      def cr_try_native_array_new(node)
        return nil unless node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead) &&
                          node.receiver_node.name == :Array && node.block_node.is_a?(Ast::Block)
        blk = node.block_node
        params = blk.required_params || []
        args = node.arg_nodes || []
        return nil unless !params.empty? && args.size == 1 && node_raw_type(args[0])&.i64? &&
                          params.all? { |p| p.is_a?(Symbol) && @mctx.block_params[p]&.i64? }
        body_str = capture do
          old_rbp = @mctx.raw_block_params
          @mctx.raw_block_params = old_rbp.merge(params.map { |p| [p, Type::I64] }.to_h)
          emit_newline
          indented { emit_native_block_body(blk.body) }
          @mctx.raw_block_params = old_rbp
          emit_newline
          emit_indent
        end
        "RubyArray.new(#{raw(args[0])}) { |#{params.map { |p| crystal_local(p) }.join(", ")}|#{body_str}}"
      end

      # n.times/upto/downto { block } when n is raw i64 → Crystal native iteration.
      def cr_try_native_iteration(node)
        return nil unless opt?(:native_iteration) && node.block_node &&
                          !node.block_node.is_a?(Ast::BlockArg) &&
                          (node.arg_nodes || []).size <= 1 && node_raw_type(node.receiver_node)&.i64?
        blk_str = ->(b) { capture { emit_native_iter_block(b) } }
        case node.name
        when :times
          "#{raw(node.receiver_node)}.times #{blk_str.call(node.block_node)}"
        when :upto
          limit = (node.arg_nodes || [])[0]
          return nil unless limit && node_raw_type(limit)&.i64?
          "(#{raw(node.receiver_node)}..#{raw(limit)}).each #{blk_str.call(node.block_node)}"
        when :downto
          limit = (node.arg_nodes || [])[0]
          return nil unless limit && node_raw_type(limit)&.i64?
          "(#{raw(limit)}..#{raw(node.receiver_node)}).reverse_each #{blk_str.call(node.block_node)}"
        end
      end

      # Typed instance method call on a class-typed receiver → emit args with declared types.
      def cr_try_typed_instance_call(node)
        return nil unless node.receiver_node.is_a?(Ast::LocalVariableRead)
        cls_entry = @mctx.class_locals[node.receiver_node.name] or return nil
        recv_class = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
        tp = @gctx.class_params[[recv_class, node.name]] or return nil
        args_str = capture { emit_typed_call_args(node.arg_nodes || [], tp) }
        "#{cr(node.receiver_node)}.#{crystal_method_name(node.name)}#{args_str}#{cr_block_if_present(node)}"
      end

      # Method call on native array local → emit raw args (Crystal Array methods expect Int, not RubyInteger)
      def cr_try_native_array_method(node)
        return nil unless node.receiver_node&.is_a?(Ast::LocalVariableRead)
        recv_name = node.receiver_node.name
        return nil unless native_array_elem_type(recv_name)
        return nil unless %i[delete_at insert push unshift].include?(node.name)
        args_str = (node.arg_nodes || []).map { |a| node_raw_type(a) ? raw(a) : cr(a) }.join(", ")
        "#{crystal_local(recv_name)}.#{crystal_method_name(node.name)}(#{args_str})"
      end

      # arr << val on native arrays → array push (not integer shift).
      def cr_try_array_push(node)
        return nil unless node.name == :<< && node.receiver_node && node.arg_nodes&.size == 1
        recv = node.receiver_node
        if recv.is_a?(Ast::LocalVariableRead) && (elem = native_array_elem_type(recv.name))
          "#{cr(recv)} << #{raw_as(node.arg_nodes[0], elem)}"
        elsif recv.is_a?(Ast::MethodCall) && recv.name == :[] &&
              recv.receiver_node.is_a?(Ast::LocalVariableRead)
          arr_elem = native_array_elem_type(recv.receiver_node.name)
          return nil unless arr_elem && arr_elem.array_scalar?
          "#{cr(recv)} << #{raw_as(node.arg_nodes[0], arr_elem.elem)}"
        end
      end

      # mc[i] where mc is Array(Array(T)) → coerce index, no boxing.
      def cr_try_native_array_read(node)
        return nil unless node.name == :[] && node.arg_nodes&.size == 1 &&
                          node.receiver_node&.is_a?(Ast::LocalVariableRead)
        recv_elem = native_array_elem_type(node.receiver_node.name)
        return nil unless recv_elem&.array_scalar? || recv_elem&.array?
        "#{crystal_local(node.receiver_node.name)}[#{coerce_i64(node.arg_nodes[0])}]"
      end

      # a[k] where a is native Array(T) in boxed context → box the element.
      def cr_try_boxed_array_read(node)
        return nil unless node.name == :[] && node.arg_nodes&.size == 1 &&
                          node.receiver_node&.is_a?(Ast::LocalVariableRead)
        arr_ty = native_array_elem_type(node.receiver_node.name) or return nil
        box_fn = arr_ty.f64? ? "RubyFloat" : "RubyInteger"
        "#{box_fn}.new(#{crystal_local(node.receiver_node.name)}[#{coerce_i64(node.arg_nodes[0])}])"
      end

      # a[k] with raw index on known array/tuple receivers → use Int64 overload.
      def cr_try_raw_index_read(node)
        return nil unless node.name == :[] && node.arg_nodes&.size == 1 && node_raw_type(node.arg_nodes[0])
        "#{cr(node.receiver_node)}[#{raw(node.arg_nodes[0])}]"
      end

      # Free call to fully-specialized method with all-raw args → raw Int64 overload.
      def cr_try_specialized_free_call(node)
        return nil unless node.receiver_node.nil? && @gctx.typed_method_returns[node.name]
        tp = @gctx.typed_params[node.name] or return nil
        args = node.arg_nodes || []
        return nil unless args.size == tp.size && args.all? { |a| node_raw_type(a) }
        "#{crystal_method_name(node.name)}(#{raw_args(args)})"
      end

      # Free call inside class → dispatch to eigenclass method (self.x).
      def cr_try_eigen_dispatch(node)
        return nil unless node.receiver_node.nil? && @cctx.eigen_methods&.include?(node.name)
        head = "self.#{crystal_method_name(node.name)}"
        if !@mctx.suppress_typed_call_args && (opt?(:call_site_types) || opt?(:method_specialization))
          tp = @gctx.inferred_params[node.name] || @gctx.class_params[[@cctx.name, node.name]]
          can_use_typed = tp&.any? { |t| t && !t.bottom? } &&
            tp.all? { |pt| !pt || pt.generic_compatible? || pt.raw? }
          if can_use_typed
            args_str = capture { emit_typed_call_args(node.arg_nodes || [], tp) }
            return "#{head}#{args_str}#{cr_block_if_present(node)}"
          end
        end
        "#{head}#{capture { emit_call_args(node) }}"
      end

      # Free call with inferred param types → coerce args.
      def cr_try_typed_free_call(node)
        return nil unless !@mctx.suppress_typed_call_args && node.receiver_node.nil?
        tp = @gctx.inferred_params[node.name] or return nil
        return nil unless tp.all? { |t| t && t.native? } || @gctx.typed_params[node.name]
        args_str = capture { emit_typed_call_args(node.arg_nodes || [], tp) }
        "#{crystal_method_name(node.name)}#{args_str}#{cr_block_if_present(node)}"
      end

      # Devirtualize: cast class-typed receiver for static dispatch.
      def cr_try_devirtualized_call(node)
        return nil unless node.receiver_node.is_a?(Ast::LocalVariableRead)
        cls_entry = @mctx.class_locals[node.receiver_node.name] or return nil
        cls = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
        "#{crystal_local(node.receiver_node.name)}.as(#{crystal_class_name(cls)}).#{crystal_method_name(node.name)}#{capture { emit_call_args(node) }}"
      end

      # Both operands raw-typed → Crystal arithmetic/comparison, skip RubyObject dispatch.
      def cr_try_raw_arithmetic(node)
        return nil unless node.receiver_node && (node.arg_nodes || []).size == 1 &&
                          (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name)
        rt = node_raw_type(node.receiver_node)
        at = node_raw_type(node.arg_nodes[0])
        return nil unless rt && at
        ty = (rt.f64? || at.f64?) ? Type::F64 : Type::I64
        op = (node.name == :/ && ty.i64?) ? "//" : node.name.to_s
        lhs = raw_as(node.receiver_node, ty)
        rhs = raw_as(node.arg_nodes[0], ty)
        if CrystalEmitter::COMPARE_OPS.include?(node.name)
          "((#{lhs} #{op} #{rhs}) ? RUBY_TRUE : RUBY_FALSE)"
        else
          "#{ty.i64? ? 'RubyInteger.new(' : 'RubyFloat.new('}#{lhs} #{op} #{rhs})"
        end
      end

      # Override: emit typed local args as raw in method calls.
      # Crystal's overload resolution picks Int64/Float64 overloads where
      # available, and *args stubs accept any type.
      def cr_call_args(node)
        return super unless opt?(:unbox_locals)
        return super if node.name == :new
        args = node.arg_nodes
        return super if args.empty? && node.kw_arg_nodes.empty? && node.block_node.nil?

        all_raw = args.all? { |a| a.is_a?(Ast::SplatArg) || raw_passable_arg?(a) }
        has_typed_overload = @gctx.typed_params&.key?(node.name) ||
          (@cctx&.name && @gctx.class_params&.key?([@cctx.name, node.name])) ||
          (node.receiver_node.is_a?(Ast::ConstantRead) && @gctx.class_params&.key?([node.receiver_node.name, node.name]))
        return super unless all_raw && has_typed_overload

        parts = args.map { |arg|
          if arg.is_a?(Ast::SplatArg) then "# UNSUPPORTED_SPLAT(#{cr(arg.value_node)})"
          elsif raw_passable_arg?(arg) then raw(arg)
          else cr(arg)
          end
        }
        node.kw_arg_nodes.each do |kw_name, val_node|
          key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
          parts << "#{key}: #{cr(val_node)}"
        end
        result = "(#{parts.join(', ')})"
        if node.block_node
          blk = node.block_node.is_a?(Ast::BlockArg) ? cr_block_arg(node.block_node) : cr_block(node.block_node)
          result += " #{blk}"
        end
        result
      end

      def emit_call_args(node) = write cr_call_args(node)

      # Override: for []= with typed array or raw-typed index, emit accordingly.
      def cr_attribute_write(node)
        try_cr_attribute_write_optimized(node) || cr_attribute_write_default(node)
      end

      def cr_attribute_write_default(node)
        name = node.name
        recv = node.receiver_node
        args = node.arg_nodes
        if name == :[]=
          "#{cr(recv)}[#{cr(args[0])}] = #{cr(args[1])}"
        else
          "#{cr(recv)}.#{name.to_s.chomp('=')} = #{cr(args[0])}"
        end
      end

      def emit_attribute_write(node) = write cr_attribute_write(node)

      def try_cr_attribute_write_optimized(node)
        return unless node.name == :[]=
        args = node.arg_nodes
        recv = node.receiver_node
        return unless args&.size == 2

        # Ivar array write: @list[i] = val where @list is Array(Float64/Int64)
        if recv.is_a?(Ast::InstanceVariableRead)
          iv_ty = @cctx&.ivars&.dig(recv.name)
          if iv_ty == Type::ARRAY_F64 || iv_ty == Type::ARRAY_I64
            val = iv_ty == Type::ARRAY_F64 ? coerce_f64(args[1]) : coerce_i64(args[1])
            return "#{recv.name}[#{coerce_i64(args[0])}] = #{val}"
          end
        end

        if recv.is_a?(Ast::LocalVariableRead)
          # Unboxed/native Array(T) write
          if (arr_ty = native_array_elem_type(recv.name))
            if args[0].is_a?(Ast::RangeLiteral)
              r = args[0]
              op = r.exclusive ? "..." : ".."
              return "#{crystal_local(recv.name)}[#{coerce_i64(r.begin_node)}#{op}#{coerce_i64(r.end_node)}] = #{cr(args[1])}"
            else
              return "#{crystal_local(recv.name)}[#{coerce_i64(args[0])}] = #{raw_as(args[1], arr_ty)}"
            end
          end
          # Boxed RubyArray with known elem type
          if (elem_ty = @mctx.local_array_elems[recv.name]) && node_raw_type(args[1])
            box = elem_ty.f64? ? "RubyFloat" : "RubyInteger"
            return "#{cr(recv)}[#{coerce_i64(args[0])}] = #{box}.new(#{raw(args[1])})"
          end
        end

        # Non-typed array with raw-typed index
        if node_raw_type(args.first)
          val = args[1]
          vt = node_raw_type(val)
          val_s = if vt&.i64? then "RubyInteger.new(#{raw(val)})"
                  elsif vt&.f64? then "RubyFloat.new(#{raw(val)})"
                  else cr(val)
                  end
          return "#{cr(recv)}[#{raw(args[0])}] = #{val_s}"
        end
        nil
      end

      # Override: for comparisons with at least one raw-typed operand, use bare
      # Crystal comparison with .to_i64/.to_f64 coercion on the untyped side.
      # Does this expression return a Crystal nilable type (T? not T | RubyNil)?
      # True for accessor reads on class_or_nil typed ivars.
      def returns_crystal_nilable?(node)
        return false unless node.is_a?(Ast::MethodCall) && node.receiver_node
        recv_class = receiver_known_class(node.receiver_node)
        return false unless recv_class
        # Check if the called method is an accessor for a class_or_nil ivar
        ct = @gctx.class_typed_ivars.dig(recv_class, :"@#{node.name}")
        ct.is_a?(Array) && ct[0] == :class_or_nil
      end

      def emit_truthy(node)
        if crystal_bool_emittable?(node)
          emit_crystal_bool(node)
          return
        end
        if opt?(:condition_simplify) && comparison_op_call?(node)
          recv = node.receiver_node
          arg = node.arg_nodes[0]
          rt = node_raw_type(recv)
          at = node_raw_type(arg)
          if rt && at
            ty = (rt.f64? || at.f64?) ? Type::F64 : Type::I64
            write "("
            ty.i64? ? emit_coerce_i64(recv) : emit_coerce_f64(recv)
            write " #{node.name} "
            ty.i64? ? emit_coerce_i64(arg) : emit_coerce_f64(arg)
            write ")"
            return
          end
        end
        # Inline base emit_truthy for remaining cases
        if node.is_a?(Ast::TrueLiteral) then write "true"
        elsif node.is_a?(Ast::FalseLiteral) then write "false"
        elsif node.is_a?(Ast::NilLiteral) then write "false"
        elsif boolean_valued?(node) then emit(node)
        elsif returns_crystal_nilable?(node) then write "!"; emit(node); write ".nil?"
        else emit(node); write ".truthy?"
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
            klass = @cc.top_level_scope.constants_table&.fetch(klass_name, nil)
            next unless klass.is_a?(Vm::ModuleObject)
            klass.methods_table&.each do |mname, method|
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
        targets = node.targets
        rhs = node.value_node

        # Typed multi-return: RHS is a call to a user method that returns a Crystal tuple.
        # Destructure directly without masgn_coerce.
        has_splat = targets.any? { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }
        if !has_splat && rhs.is_a?(Ast::MethodCall) && rhs.receiver_node.nil?
          method_name = rhs.name
          method = @cc.top_level_scope.methods_table&.fetch(method_name, nil)
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
          elems = rhs.element_nodes || []
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
              name = t[1]
              elem = elems[i]
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
        if target[0] == :ivar && (ty = @cctx.ivars[target[1]])
          coerce = ty.f64? ? ".to_f64" : ".to_i64"
          write "#{target[1]} = #{value_code}#{coerce}"
        elsif (target[0] == :local || target[0] == :local_splat) &&
              (ty = @mctx.typed_locals[target[1]])
          coerce = ty.f64? ? ".to_f64" : ".to_i64"
          write "#{crystal_local(target[1])} = #{value_code}#{coerce}"
        elsif (target[0] == :index || target[0] == :index_splat) &&
              target[1].is_a?(Ast::LocalVariableRead) &&
              (nat_ty = native_array_elem_type(target[1].name))
          # Native Array(T) index write: coerce index to Int64 and value to T
          coerce = nat_ty.f64? ? ".to_f64" : ".to_i64"
          write "#{crystal_local(target[1].name)}["
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
      def accessor_method?(method) = method.body.is_a?(Ast::InstanceVariableRead) || method.body.is_a?(Ast::InstanceVariableWrite)

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
          iv = body.name
          case @cctx.ivars[iv]
          when Type::F64
            line "def #{crystal_method_name(mname)} : RubyObject; RubyFloat.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Float64; #{iv}; end"
          when Type::I64
            line "def #{crystal_method_name(mname)} : RubyObject; RubyInteger.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Int64; #{iv}; end"
          else
            ct = @cctx.typed_ivars[iv]
            if ct
              kind, cls = ct
              crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
              ret_type = (kind == :class_or_nil && cls == @cctx.name) ? "#{crystal_cls}?" : crystal_cls
              line "def #{crystal_method_name(mname)} : #{ret_type}; #{iv}; end"
            else
              line "def #{crystal_method_name(mname)} : RubyObject; #{iv}; end"
            end
          end
        when Ast::InstanceVariableWrite
          iv = body.name
          case @cctx.ivars[iv]
          when Type::F64
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_f64; v; end"
          when Type::I64
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_i64; v; end"
          else
            ct = @cctx.typed_ivars[iv]
            if ct && ct[0] == :class_or_nil && ct[1] == @cctx.name
              crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[ct[1]] || "Ruby_#{crystal_constant(ct[1])}"
              line "def #{crystal_method_name(mname)}(v : #{crystal_cls}) : #{crystal_cls}; #{iv} = v; end"
              line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.as(#{crystal_cls}); end"
              line "def #{crystal_method_name(mname)}(v : RubyNil) : Nil; #{iv} = nil; end"
            else
              line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v; end"
            end
          end
        end
      end
    end
  end
end
