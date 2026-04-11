require_relative 'crystal_emitter'
require_relative 'type_mapper'
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
      #
      # The four `typed_ivars / unbox_locals / call_site_types /
      # method_specialization` flags must travel together or not at
      # all — they form an interlocking type-information pipeline
      # that the codegen relies on for typed Float64 dispatch:
      #
      #   - call_site_types  infers param types from call sites
      #   - method_specialization emits raw Int64/Float64 method
      #     overloads that those typed call sites can dispatch to
      #   - unbox_locals     keeps the raw values unboxed across the
      #     specialized method body
      #   - typed_ivars      types `@field` ivars so wrapper classes
      #     (Ruby_ThreeDArray etc) compile cleanly
      #
      # Removing any one of them at -O1 broke blurhash: at minimum
      # the -O1 build either failed (Crystal couldn't infer the
      # nilable index return type) or produced wrong float output
      # (call sites passed boxed values to a generic overload that
      # silently coerced).
      OPT_LEVELS = {
        0 => [],
        1 => %i[typed_ivars unbox_locals call_site_types method_specialization
                native_arrays tuple_literals devirtualize condition_simplify
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
      # Crystal integer-literal suffixes for narrow integer types.
      # Used by storage-narrowing in vm_value_to_crystal — when an
      # all-Integer constant array's element bounds fit in a smaller
      # type than Int64, we emit per-element literals with the
      # corresponding suffix.
      CRYSTAL_INT_SUFFIX = {
        "UInt8"  => "u8",   "Int8"  => "i8",
        "UInt16" => "u16",  "Int16" => "i16",
        "UInt32" => "u32",  "Int32" => "i32",
        "UInt64" => "u64",  "Int64" => "i64",
      }.freeze

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

        # Pre-pass: walk every emittable subtree to collect literal symbol
        # values (`:foo`) so the header can declare each unique one as a
        # static `Ruby_Sym_<i>` constant. Call sites then reference the
        # constant instead of calling RubySymbol.from at runtime.
        collect_symbol_literals_from_scope(top_level_scope)
        collect_symbol_literals(execute_block.body) if execute_block
        collect_string_constants_from_scope(top_level_scope)

        emit_header
        emit_bench_harness_require if bench_stub?
        emit_literal_symbols unless @literal_symbols.empty? && @literal_arrays.empty? && @literal_strings.empty?
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

      # Walk every user-defined method body in the scope (and all nested
      # classes/modules) collecting literal symbol values into
      # @literal_symbols. Mirrors collect_user_methods_from_scope's
      # traversal so symbols inside class methods get registered too.
      def collect_symbol_literals_from_scope(scope, visited = Set.new)
        return if visited.include?(scope.object_id)
        visited << scope.object_id
        scope.methods_table&.each do |_name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)
          collect_symbol_literals(method.body) if method.body
        end
        scope.constants_table&.each do |_name, value|
          next unless value.is_a?(Vm::ModuleObject)
          collect_symbol_literals_from_scope(value, visited)
        end
      end

      # Pre-register settled StringObject constants for hoisting. Top-level
      # constants like `TEST_STR = "..."` get serialised by
      # vm_value_to_crystal, which bypasses cr_string entirely; without
      # this pre-pass their string value would never reach @literal_strings
      # and so couldn't share with the same literal appearing in source.
      def collect_string_constants_from_scope(scope, visited = Set.new)
        return if visited.include?(scope.object_id)
        visited << scope.object_id
        scope.constants_table&.each do |name, value|
          next if SKIP_CONSTANTS.include?(name)
          if value.is_a?(Vm::StringObject)
            @literal_strings[value.raw] ||= @literal_strings.size
          elsif value.is_a?(Vm::ModuleObject)
            collect_string_constants_from_scope(value, visited)
          end
        end
      end

      # -----------------------------------------------------------------------
      # Emit user-defined classes/modules
      # -----------------------------------------------------------------------

      def emit_user_classes(scope, visited = Set.new)
        return if visited.include?(scope.object_id)
        visited << scope.object_id

        const_locs = scope.constants_locations || {}
        top_level = scope.equal?(Vm::Core::OBJECT_CLASS)
        scope.constants_table&.each do |name, value|
          next unless value.is_a?(Vm::ModuleObject)
          next if top_level && SKIP_CONSTANTS.include?(name)
          emit_user_class(name, value, const_loc: const_locs[name], visited: visited)
        end
      end

      # Check whether a module has any nested user-defined content (classes,
      # modules, or methods with user source locations). Used to decide
      # whether a namespace-only module needs a Crystal wrapper.
      def has_user_descendants?(mod, visited = Set.new)
        return false if visited.include?(mod.object_id)
        visited << mod.object_id
        const_locs = mod.constants_locations || {}
        mod.constants_table&.any? do |name, value|
          next false unless value.is_a?(Vm::ModuleObject)
          next false if SKIP_CONSTANTS.include?(name)
          loc = const_locs[name]
          user_source_location?(loc) ||
            value.methods_table&.any? { |_, m| m.is_a?(Vm::Method) && user_source_location?(m.source_location) } ||
            has_user_descendants?(value, visited)
        end
      end

      def emit_user_class(name, mod, const_loc: nil, visited: Set.new)
        # Struct subclasses (`TheClass = Struct.new(:v0, :v1, :v2, :levar)`)
        # don't have Vm::Method accessors — they're DefinedMethod blocks
        # generated via define_method in lib/core/4.0/struct.rb. The
        # codegen can't emit those directly, so synthesise a normal class
        # definition with positional-arg initialize and per-member
        # accessors instead.
        if mod.is_a?(Vm::ClassObject) && struct_subclass?(mod) && mod.name != :Struct
          emit_struct_subclass(name, mod)
          return
        end

        user_methods = collect_class_user_methods(mod)
        has_own = user_methods.any? { |_, m| user_source_location?(m.source_location) } ||
                  user_source_location?(const_loc)

        if has_own
          emit_class_header(name, mod)
          old_cctx = @cctx
          @cctx = ClassContext.new
          @cctx.name = name
          @cctx.ivars = @gctx.typed_ivars.fetch(name, {})
          @cctx.typed_ivars = @gctx.class_typed_ivars.fetch(name, {})
          @cctx.parent_ivars = collect_parent_ivars(mod)

          indented do
            emit_ivar_declarations(user_methods)
            emit_default_stringifiers(name, user_methods)
            emit_user_constants(mod)
            emit_newline
            eigen_names = collect_eigen_method_names(mod)
            emit_instance_methods(name, user_methods, eigen_names)
            emit_class_methods(name, mod, eigen_names)
            emit_respond_to(mod) if mod.is_a?(Vm::ClassObject)
            emit_user_classes(mod, visited)
          end

          @cctx = old_cctx
          @cctx.eigen_methods = nil
          emit_indent
          write "end"
          emit_newline
        elsif has_user_descendants?(mod)
          # Namespace-only module: no user methods, but has nested user content.
          # Emit a Crystal module wrapper so nested classes land at the right scope.
          emit_indent
          write "module Ruby_#{crystal_constant(name)}"
          emit_newline
          indented { emit_user_classes(mod, visited) }
          emit_indent
          write "end"
          emit_newline
        end
      end

      # Emit a Struct subclass as a plain Crystal class with one ivar /
      # accessor pair per declared member and an initialize accepting
      # positional args in declaration order.
      def emit_struct_subclass(name, cls)
        members = struct_members_for(cls)
        return if members.nil? || members.empty?

        crystal_name = "Ruby_#{crystal_constant(name)}"
        emit_indent
        write "class #{crystal_name} < RubyObject"
        emit_newline

        indented do
          # ivar declarations
          members.each do |m|
            line "@#{m} : RubyObject = RUBY_NIL"
          end
          emit_newline

          # to_s / inspect (mirrors emit_default_stringifiers behaviour)
          line "def to_s : String; \"#<#{name}>\"; end"
          line "def inspect : String; \"#<#{name}>\"; end"
          emit_newline

          # initialize accepting positional args, one per member, all
          # defaulting to RUBY_NIL so callers can construct with fewer
          # args if they wish (matching Struct semantics).
          init_params = members.map { |m| "@#{m} : RubyObject = RUBY_NIL" }.join(", ")
          line "def initialize(#{init_params}); end"
          emit_newline

          # Per-member reader and writer accessors.
          members.each do |m|
            line "def #{m} : RubyObject; @#{m}; end"
            line "def #{m}=(v : RubyObject) : RubyObject; @#{m} = v; v; end"
          end
          emit_newline

          # respond_to? table — same shape as the normal class emission.
          emit_respond_to(cls)
        end

        emit_indent
        write "end"
        emit_newline
      end

      # Read the @members array from a Struct subclass and return an
      # Array of Ruby Symbols, or nil if the class has no members.
      def struct_members_for(cls)
        members_obj = cls.get_ivar(:@members)
        return nil unless members_obj.respond_to?(:raw)
        members_obj.raw.map { |sym_obj| sym_obj.respond_to?(:raw) ? sym_obj.raw : sym_obj.to_sym }
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
        emit_indent
        write "#{kw} Ruby_#{crystal_constant(name)}"
        if is_class
          sc = mod.superclass
          sc_name = sc&.name
          if sc_name && !%i[Object BasicObject Struct Data].include?(sc_name)
            write " < #{crystal_superclass_path(sc)}"
          else
            write " < RubyObject"
          end
        end
        emit_newline
      end

      # Build the fully-qualified Crystal path for a superclass reference.
      # Walks the namespace chain to produce Ruby_Outer::Ruby_Inner::Ruby_Name,
      # avoiding collisions when parent and child share a bare name (e.g.
      # AST::Node vs Parser::AST::Node).
      # Build the fully-qualified Crystal path for a superclass reference.
      # Uses :: prefix to anchor at the top level, avoiding shadowing
      # when a parent module re-opens a namespace (e.g. Parser::AST
      # shadows top-level AST).
      def crystal_superclass_path(cls)
        parts = []
        current = cls
        while current && !current.equal?(Vm::Core::OBJECT_CLASS)
          parts.unshift("Ruby_#{crystal_constant(current.name)}") if current.name
          current = current.namespace
        end
        "::#{parts.join('::')}"
      end

      def emit_ivar_declarations(user_methods)
        all_ivars = user_methods.each_with_object([]) do |(_, m), acc|
          acc.concat(collect_ivars(m.body)) if m.body
        end.uniq
        # Skip ivars declared by ancestor classes — Crystal forbids
        # re-declaring inherited ivars with a different type.
        parent_ivars = @cctx.parent_ivars
        all_ivars.reject! { |iv| parent_ivars.include?(iv) } unless parent_ivars.empty?
        all_ivars.each do |iv|
          type_ann, default = ivar_type_annotation(iv.to_sym)
          emit_indent
          line "#{iv} : #{type_ann} = #{default}"
        end
        emit_newline unless all_ivars.empty?
      end

      # Collect ivar names declared by all ancestor user classes.
      def collect_parent_ivars(mod)
        return Set.new unless mod.is_a?(Vm::ClassObject)
        result = Set.new
        sc = mod.superclass
        while sc && !sc.equal?(Vm::Core::OBJECT_CLASS)
          sc_name = sc.name
          if sc_name && !SKIP_CONSTANTS.include?(sc_name)
            sc_methods = collect_class_user_methods(sc)
            sc_methods.each do |_, m|
              result.merge(collect_ivars(m.body)) if m.body
            end
          end
          sc = sc.is_a?(Vm::ClassObject) ? sc.superclass : nil
        end
        result
      end

      def ivar_type_annotation(iv_sym)
        ivt = @cctx.ivars[iv_sym]
        return ["Float64", "0.0_f64"] if ivt&.f64?
        return ["Int64", "0_i64"] if ivt&.i64?
        return ["Array(Float64)", "Array(Float64).new"] if (ivt) == Type::ARRAY_F64
        return ["Array(Int64)", "Array(Int64).new"] if (ivt) == Type::ARRAY_I64
        ct = @cctx.typed_ivars[iv_sym]
        return ["RubyObject", "RUBY_NIL"] unless ct
        kind, cls = ct
        crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
        # Self-referential class-or-nil ivars (e.g. Node@left → Ruby_Node | RubyNil).
        # Use the boxed-nil form so the value flows uniformly through other ivars
        # of the same union type (e.g. SplayTree@root).
        return ["#{crystal_cls} | RubyNil", "RUBY_NIL"] if kind == :class_or_nil && cls == @cctx.name
        default = { Array: "RubyArray.new", Hash: "RubyHash.new", String: "RubyString.new" }[cls]
        default ? [crystal_cls, default] : ["#{crystal_cls} | RubyNil", "RUBY_NIL"]
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
        has_typed = inst_param_types&.any? { |t| t && t != :ruby_object }
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
        # Emit eigenclass attr_accessor getters (DefinedMethod) that hold
        # settled values from the load phase — e.g. Ragel state machine
        # constants like lex_en_line_begin = 710.
        emit_eigenclass_accessors(mod, eigenclass)
      end

      def emit_eigenclass_accessors(mod, eigenclass)
        eigenclass.methods_table&.each do |mname, method|
          next if mname.to_s.end_with?('=')  # skip setters
          # Include Vm::Method accessors (attr_accessor from core) that
          # have settled values — e.g. Ragel state machine constants.
          next unless accessor_method?(method)
          # Eigenclass attr_accessor: value stored on the class object itself
          val = mod.get_ivar(:"@#{mname}") || eigenclass.get_ivar(:"@#{mname}")
          $stderr.puts "DBG eigen_acc #{mname}: val=#{val&.class} #{val.respond_to?(:raw) ? val.raw : val}" if ENV['FROZONE_DBG_EIGEN']
          next unless val
          crystal_val = vm_value_to_crystal(val)
          next unless crystal_val
          emit_indent
          line "def self.#{crystal_method_name(mname)} : RubyObject; #{crystal_val}; end"
        end
      end

      def emit_class_method_overloads(class_name, mname, method)
        class_param_types = @gctx.class_params[[class_name, mname]] || @gctx.inferred_params[mname]
        raw_types = class_param_types&.map { |t| t&.raw? ? t : nil }
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
          next unless method.is_a?(Vm::Method) && user_source_location?(method.source_location)
          user_methods_on_object << [name, method]
          emit_top_level_method_overloads(name, method)
        end
        emit_top_level_method_object_copies(user_methods_on_object)
      end

      # Emit every overload for a single top-level method: the
      # raw-typed-params specialised version, the typed (some/all
      # native or class-typed) version, and the always-emitted generic
      # RubyObject fallback that the execute block and untyped callers
      # use.
      def emit_top_level_method_overloads(name, method)
        emit_specialized_top_level_overload(name, method)
        inferred = @gctx.inferred_params[name]
        has_complex_params = !@gctx.typed_params[name] && inferred&.any? { |t| complex_native_type?(t) }
        emit_typed_top_level_overload(name, method, inferred) if has_complex_params

        all_native = inferred&.all? { |t| t&.native? }
        # Mixed-raw: at least one param is raw scalar, but not all are
        # native. Worth a typed overload so the body avoids boxing on
        # the raw param (e.g. generate_payload(depth : Int64, tag : RubyObject)).
        some_raw = inferred&.any? { |t| t&.raw? }
        skip_typed = has_complex_params || (@gctx.typed_params[name] && @gctx.typed_method_returns[name])
        emit_typed_top_level_overload(name, method, inferred) if (all_native || some_raw) && !skip_typed

        generic_params = compute_generic_top_level_params(name, inferred, has_complex_params, all_native, some_raw)
        emit_indent
        emit_vm_method(name, method, param_types: generic_params)
        emit_newline
        emit_newline
      end

      # Specialised raw-typed overload (Int64/Float64 args + return),
      # only emitted when method_specialization is on AND TI has both
      # the typed_params and typed_method_returns slots populated.
      def emit_specialized_top_level_overload(name, method)
        return unless opt?(:method_specialization) &&
                      @gctx.typed_params[name] &&
                      @gctx.typed_method_returns[name]
        emit_indent
        emit_specialized_vm_method(name, method)
        emit_newline
        emit_newline
      end

      def emit_typed_top_level_overload(name, method, inferred)
        emit_indent
        emit_vm_method(name, method, param_types: inferred)
        emit_newline
        emit_newline
      end

      # Compute the param_types tuple for the generic (all-RubyObject /
      # devirtualised) fallback overload. Five cases:
      #   - complex params: drop natives to BOTTOM, keep rest
      #   - fully typed:   nil → all RubyObject
      #   - all/some raw:  nil → all RubyObject (typed overload covers raw)
      #   - default:       drop raw scalars to BOTTOM, keep class types
      def compute_generic_top_level_params(name, inferred, has_complex_params, all_native, some_raw)
        if has_complex_params
          inferred.map { |t| t&.native? ? Type::BOTTOM : t }
        elsif @gctx.typed_params[name]
          nil
        elsif all_native || some_raw
          nil
        else
          inferred&.map { |t| t&.raw? ? Type::BOTTOM : t }
        end
      end

      # Also emit each top-level user method as an instance method on
      # RubyObject so receiver-based calls (`obj.foo`) dispatch through
      # Crystal's virtual dispatch. Mirrors Ruby semantics where Object
      # methods are available both as bare functions and as instance
      # methods.
      def emit_top_level_method_object_copies(user_methods_on_object)
        @cc.object_instance_methods = user_methods_on_object.map(&:first).to_set
        return if user_methods_on_object.empty?
        # Methods where every param is native already have the typed
        # overload; no generic instance method needed.
        generic_methods = user_methods_on_object.reject do |name, _|
          inferred = @gctx.inferred_params[name]
          inferred&.all? { |t| t&.native? }
        end
        return if generic_methods.empty?
        line "# User methods on Object — also available as instance methods"
        line "class RubyObject"
        generic_methods.each do |name, method|
          emit_indent
          write "  "
          emit_vm_method(name, method, param_types: nil)
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
        param_set = collect_param_set(method)
        mkey = @cctx.name ? [@cctx.name, name] : name

        setup_method_context(name, method, param_types: param_types,
                             class_method: class_method, param_set: param_set, mkey: mkey)
        @mctx.class_method = class_method
        @mctx.current_method_obj = method
        register_native_array_locals(method, param_types, param_set)
        infer_method_local_types(name, method, param_types, param_set, class_method)

        return_kind = compute_return_kind(name, param_types, class_method)
        emit_method_signature(name, method, param_types, class_method, return_kind)
        emit_method_body(method, name, return_kind)

        emit_newline
        emit_indent
        write "end"
      ensure
        @mctx = old_mctx
      end

      # Set of every parameter name (positional, optional, rest, post)
      # for use as the local-types exclusion set during context setup.
      def collect_param_set(method)
        ((method.required_params || []) +
         (method.optional_params || []).map(&:first) +
         [method.rest_param].compact +
         (method.post_params || [])).to_set
      end

      # True when this method def should disable type optimisations
      # because a specialized class-method overload covers the raw path.
      def generic_with_specialized?(name, class_method)
        class_method && @cctx.eigen_methods&.any? &&
          (@gctx.inferred_params[name] || @gctx.class_params[[@cctx.name, name]])&.any? { |t| t != :ruby_object }
      end

      def setup_method_context(name, method, param_types:, class_method:, param_set:, mkey:)
        @mctx = MethodContext.new
        @mctx.param_set = param_set
        no_opts = generic_with_specialized?(name, class_method) && param_types.nil?
        @mctx.suppress_typed_call_args = no_opts
        @mctx.typed_locals       = (!no_opts && opt?(:unbox_locals))    ? reject_params(@gctx.locals[mkey], param_set) : {}
        @mctx.typed_array_locals = opt?(:native_arrays)                 ? reject_params(@gctx.arrays[mkey], param_set) : {}
        @mctx.class_locals       = opt?(:devirtualize)                  ? reject_params(@gctx.class_locals[mkey], param_set, keep_params: !param_types.nil?) : {}
        @mctx.local_array_elems  = opt?(:native_arrays)                 ? reject_params(@gctx.local_array_elems[mkey], param_set) : {}
        @mctx.block_params       = reject_params(@gctx.block_params[mkey], param_set)
        @mctx.local_types        = reject_params(@gctx.local_types[mkey], param_set)
        @mctx.method_body        = method.body
        @mctx.block_param_name   = method.block_param
        @mctx.native_array_locals = {}
      end

      # Filter a {name => Type} hash, dropping entries whose name is a
      # method parameter (params have declared types so they don't need
      # the inferred-locals shadow). When `keep_params:` is true, the
      # filter is a no-op (used by class_locals when param_types is set:
      # the typed-overload path keeps every entry).
      def reject_params(hash, param_set, keep_params: false)
        return {} unless hash
        keep_params ? hash : hash.reject { |k, _| param_set.include?(k) }
      end

      # Populate @mctx.native_array_locals from three sources:
      #   1. Nested Array.new(n) { Array.new(m, fill) } literal patterns
      #   2. Param-typed Array(T) declarations
      #   3. TI-inferred Array(Array(T)) locals
      #   4. Locals assigned from nested_array[i] reads
      def register_native_array_locals(method, param_types, param_set)
        if opt?(:native_arrays)
          detect_nested_array_locals(method.body, param_set).each do |lname, inner_elem|
            @mctx.native_array_locals[lname] = Type.array(elem: inner_elem)
          end
        end
        register_typed_param_locals(method, param_types) if param_types
        register_ti_nested_arrays(param_set) if opt?(:native_arrays)
        register_aliased_native_arrays(method) if opt?(:native_arrays) && @mctx.local_array_elems.any?
      end

      # Map raw/Array/class-typed positional params into @mctx so the
      # body's node_raw_type / native-array / devirtualization paths
      # see them.
      def register_typed_param_locals(method, param_types)
        (method.required_params || []).each_with_index do |p, i|
          pt = param_types[i]
          if pt&.raw?
            @mctx.typed_locals[p] = pt
          elsif pt&.array_like?
            inner = pt.elem
            @mctx.native_array_locals[p] = inner if inner&.native?
          elsif pt&.class_type? && !pt.array? && !pt.hash_type?
            @mctx.class_locals[p] = pt.class_name
          end
        end
      end

      # Pre-register Array(Array(T)) locals from TI so nested
      # construction / read / write paths emit native code.
      def register_ti_nested_arrays(param_set)
        @mctx.local_types.each do |lname, ty|
          next if @mctx.native_array_locals.key?(lname) || param_set.include?(lname)
          next unless ty&.array_like? && ty.elem&.array_like?
          @mctx.native_array_locals[lname] = ty.elem
        end
      end

      # Pre-register locals assigned from nested_array[i] reads. Must
      # run after param seeding so Array(Array(T)) params are visible.
      def register_aliased_native_arrays(method)
        assignments = Hash.new { |h, k| h[k] = [] }
        collect_local_assignments(method.body, assignments)
        @mctx.local_array_elems.each do |lname, elem_ty|
          next if @mctx.native_array_locals.key?(lname)
          (assignments[lname] || []).each do |rhs|
            next unless rhs.is_a?(Ast::MethodCall) && rhs.name == :[]
            recv = rhs.receiver_node
            next unless recv.is_a?(Ast::LocalVariableRead)
            recv_elem = @mctx.native_array_locals[recv.name]
            if recv_elem.is_a?(Type) && recv_elem.array_like?
              @mctx.native_array_locals[lname] = elem_ty
              break
            end
          end
        end
      end

      # Infer types from literal assignments for locals TI didn't cover.
      # Skipped for generic class method overloads with a specialized
      # version (typed locals in the generic cause Float64/Int64
      # mismatches with the RubyObject path).
      def infer_method_local_types(name, method, param_types, param_set, class_method)
        return if generic_with_specialized?(name, class_method) && param_types.nil?
        infer_local_types(method.body).each do |lname, ty|
          @mctx.typed_locals[lname] ||= ty unless param_set.include?(lname)
        end
      end

      # Returns [string_return?, bool_return?, raw_return_type_or_nil].
      # Captures the three mutually-conditioned return-type variants
      # used by emit_method_signature and emit_method_body.
      def compute_return_kind(name, param_types, class_method)
        string_return = STRING_RETURN_METHODS.include?(name)
        bool_return = %i[== != < <= > >= equal?].include?(name) && !class_method
        has_specialized = generic_with_specialized?(name, class_method)
        has_any_raw_param = param_types&.any? { |t| t&.raw? }
        raw_return = has_any_raw_param && !has_specialized && opt?(:raw_returns) && !@gctx.typed_params[name] &&
          (@gctx.typed_method_returns[name] ||
           (@cctx.name && @gctx.instance_method_raw_returns[[@cctx.name, name]]))
        [string_return, bool_return, raw_return]
      end

      def emit_method_signature(name, method, param_types, class_method, return_kind)
        string_return, bool_return, raw_return = return_kind
        crystal_name = string_return ? name.to_s : crystal_method_name(name)
        write class_method ? "def self.#{crystal_name}" : "def #{crystal_name}"
        write cr_param_list(method, param_types: param_types)
        write " : String" if string_return
        write " : Bool" if bool_return && !string_return
        write " : #{raw_return.to_crystal}" if raw_return && !bool_return
        emit_newline
      end

      def emit_method_body(method, name, return_kind)
        @_declared_locals = Set.new
        string_return, bool_return, raw_return = return_kind
        if bool_return
          @mctx.bool_return = true
          indented do
            write "((begin"
            emit_newline
            indented { emit(method.body) }
            emit_newline
            emit_indent
            write "end) || RUBY_NIL).truthy?"
          end
          @mctx.bool_return = false
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
          indented {
            lines = raw_lines(method.body)
            lines.each_with_index { |l, i| emit_indent if i > 0; write l; emit_newline if i < lines.size - 1 }
          }
        else
          # Emit Crystal tuple return when method is called in masgn context.
          @mctx.emit_crystal_tuple = @cc.masgn_return_methods&.include?(name)
          indented { emit(method.body) }
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
        when Vm::StringObject
          if (idx = @literal_strings[value.raw])
            "Ruby_Str_#{idx}"
          else
            "RubyString.new(#{value.raw.inspect})"
          end
        when Vm::NilObject then "RUBY_NIL"
        when Vm::TrueObject then "RUBY_TRUE"
        when Vm::FalseObject then "RUBY_FALSE"
        when Vm::SymbolObject then "RubySymbol.from(#{value.raw.to_s.inspect})"
        when Vm::ArrayObject
          # Native Array(T) for constants confirmed by TI as all-integer.
          # We pick the narrowest Crystal int type that fits the actual
          # element bounds — Array(UInt8) for byte tables, Array(Int16)
          # for small-signed, etc. The typed-overload generator now
          # consults the same bounds via to_crystal_storage so its
          # parameter types match.
          if const_name && (@gctx.const_raw_types[const_name]) == Type::ARRAY_I64
            min = value.raw.map { |e| e.raw }.min
            max = value.raw.map { |e| e.raw }.max
            elem_ty = Type.i64_bounded(min, max)
            narrow = elem_ty.narrowest_int_type || "Int64"
            suffix = CRYSTAL_INT_SUFFIX[narrow]
            elems = value.raw.map { |e| "#{e.raw}_#{suffix}" }.join(', ')
            return "[#{elems}] of #{narrow}"
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
        when Vm::HashObject
          pairs = value.raw.map do |k, v|
            ck = vm_value_to_crystal(k)
            cv = vm_value_to_crystal(v)
            (ck && cv) ? [ck, cv] : nil
          end
          return nil if pairs.any?(&:nil?) || pairs.size > 500
          if pairs.empty?
            "RubyHash.new"
          else
            sets = pairs.map { |ck, cv| "h[#{ck}] = #{cv}" }.join("; ")
            "RubyHash.new.tap { |h| #{sets} }"
          end
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
      def complex_native_type?(t) = t&.array_like? && t.elem&.array_like?
      def returns_array_literal?(body) = last_body_expression(body).is_a?(Ast::ArrayLiteral)

      def run_type_inference(execute_block, top_level_scope)
        if ENV["FROZONE_DBG_STRUCT2"]
          cls = top_level_scope.constants_table&.[](:TheClass)
          if cls
            mem = cls.get_ivar(:@members)
            STDERR.puts "DBG2 sup=#{cls.superclass.inspect[0..60]}"
            STDERR.puts "DBG2 sup name: #{cls.superclass&.name.inspect}"
            STDERR.puts "DBG2 ancestors: #{cls.ancestors_list.map { |c| c.name }.inspect}"
            STDERR.puts "DBG2 mem: #{mem.respond_to?(:raw) ? mem.raw.inspect : mem.inspect}"
          end
        end
        user_methods_hash = {}
        top_level_scope.methods_table&.each do |name, m|
          user_methods_hash[name] = m if m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end
        user_classes_hash = {}
        collect_user_classes_recursive(top_level_scope, user_classes_hash)
        @gctx.user_class_names = user_classes_hash.keys.to_set

        # Index Method#uses_block for call-site block elision (see cr_call_args).
        user_methods_hash.each do |mname, m|
          @gctx.method_uses_block[[nil, mname]] = m.uses_block != false
        end
        user_classes_hash.each do |cname, klass|
          (klass.methods_table || {}).each do |mname, m|
            next unless m.is_a?(Vm::Method) && user_source_location?(m.source_location)
            @gctx.method_uses_block[[cname, mname]] = m.uses_block != false
          end
        end

        all_constants = top_level_scope.constants_table || {}
        ti = TypeInference.new(
          user_methods: user_methods_hash,
          user_classes: user_classes_hash,
          execute_block: execute_block,
          constants: all_constants.dup
        )
        env = ti.run

        # Delegate all type-to-Crystal mapping to TypeMapper
        mapper = TypeMapper.new(env,
          user_methods: user_methods_hash,
          user_classes: user_classes_hash,
          opt_flags: @opt_flags
        ).build!

        @gctx.load_from_mapper!(mapper)

        # Extract kwarg types from TI env
        env.slots.each do |slot, ty|
          next unless slot.is_a?(Array) && slot[0] == :kwparam && ty != :unknown
          mkey, kw_name = slot[1], slot[2]
          ct = Type.from_ti(Type.from_legacy(ty), user_class_names: @gctx.user_class_names)
          (@gctx.inferred_kw_params[mkey] ||= {})[kw_name] = ct unless ct.bottom?
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

      def cr_crystal_bool(node)
        case node
        when Ast::And then "(#{cr_crystal_bool(node.left_node)} && #{cr_crystal_bool(node.right_node)})"
        when Ast::Or  then "(#{cr_crystal_bool(node.left_node)} || #{cr_crystal_bool(node.right_node)})"
        when Ast::MethodCall
          rt = node_raw_type(node.receiver_node)
          at = node_raw_type(node.arg_nodes[0])
          ty = (rt&.f64? || at&.f64?) ? Type::F64 : Type::I64
          recv_str = raw_as(node.receiver_node, ty)
          recv_str = "(#{recv_str})" if recv_contains_assignment?(node.receiver_node)
          "(#{recv_str} #{node.name} #{raw_as(node.arg_nodes[0], ty)})"
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral then "false"
        end
      end

      def cr_and(node) = crystal_bool_emittable?(node) ? cr_crystal_bool(node) : super
      def cr_or(node) = crystal_bool_emittable?(node) ? cr_crystal_bool(node) : super

      # Override: for prepended methods, `super` calls the renamed original
      # instead of Crystal's built-in `super`. The super target mapping is
      # set by ModuleErasure.flatten! on the class.
      def cr_super(node)
        if @mctx&.current_method_obj && @cctx&.name
          cls = lookup_vm_class(@cctx.name)
          targets = cls&.prepend_super_targets
          if targets
            renamed = targets[@mctx.current_method_obj.object_id]
            if renamed
              args = node.arg_nodes
              if node.forwarding || args.nil? || args.empty?
                # Forwarding super: pass the current method's params.
                method = @mctx.current_method_obj
                param_names = (method.required_params || []).map { |p| crystal_local(p) }
                return param_names.empty? ? crystal_method_name(renamed).to_s :
                  "#{crystal_method_name(renamed)}(#{param_names.join(', ')})"
              else
                return "#{crystal_method_name(renamed)}(#{args.map { |a| cr(a) }.join(', ')})"
              end
            end
          end
        end
        # Default: regular Crystal super
        args = node.arg_nodes
        return "super" if node.forwarding || args.nil? || args.empty?
        "super(#{args.map { |a| cr(a) }.join(', ')})"
      end

      # Override cr_param_list to apply inferred types for required params.
      def cr_param_list(node, param_types: nil)
        return super(node) unless param_types
        mkey = @cctx.name ? [@cctx.name, node.name] : node.name
        kw_types = @gctx.inferred_kw_params[mkey] || {}

        parts = []
        req = node.required_params || []
        types = param_types + [Type::BOTTOM] * [req.size - param_types.size, 0].max
        req.each_with_index { |p, i| parts << "#{crystal_local(p)} : #{(types[i] || Type::BOTTOM).to_crystal}" }

        node.optional_params.each { |p, default| parts << "#{crystal_local(p)} : RubyObject = #{default ? "(#{codegen_inline(default)})" : 'RUBY_NIL'}" }
        rp = node.rest_param
        parts << "*#{crystal_local(rp)} : RubyObject" if rp
        node.post_params.each { |p| parts << "#{crystal_local(p)} : RubyObject" }
        req_kw = node.required_kw_params || []
        opt_kw = node.optional_kw_params || []
        kr = node.kw_rest_param
        parts << "*" if (!req_kw.empty? || !opt_kw.empty?) && !rp
        req_kw.each do |p|
          ct = kw_types[p]
          parts << "#{crystal_local(p)} : #{ct ? ct.to_crystal : 'RubyObject'}"
        end
        opt_kw.each do |p, default|
          ct = kw_types[p]
          if ct&.raw? && default
            raw_default = ct.i64? ? "#{default.value.raw}_i64" : "#{default.value.raw}_f64"
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
        parts.empty? ? "" : "(#{parts.join(', ')})"
      end

      # Map a class name symbol to the Crystal class name.
      # Uses RUBY_TO_CRYSTAL_TYPE for built-in classes, Ruby_ prefix for user classes.
      def crystal_class_name(cls) = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"

      # Override: inside Bool-return methods (==, <, etc.), convert return values
      # to Crystal Bool so early returns match the : Bool annotation.
      def cr_return(node)
        return super unless @mctx.bool_return && node.value_node
        "return #{cr(node.value_node)}.truthy?"
      end

      # Override: for typed locals in boxed context, wrap in RubyInteger/RubyFloat.
      def cr_local_read(node)
        name = node.name
        ty = @mctx.typed_locals[name] || @mctx.raw_block_params[name]
        return "RubyInteger.new(#{crystal_local(name)})" if ty&.i64?
        return "RubyFloat.new(#{crystal_local(name)})" if ty&.f64?
        crystal_local(name)
      end

      # Override: for typed locals, emit RHS as bare Crystal numeric.
      # For typed array locals, emit Array(T).new construction.
      # For class-typed locals, add .as(Ruby_ClassName) cast for static dispatch.
      def cr_local_write(node)
        name = node.name
        result = cr_try_nested_array_write(node, name) ||
          cr_try_range_to_a_write(node, name) ||
          cr_try_native_dup_write(node, name) ||
          cr_try_typed_array_write(node, name) ||
          cr_try_boxed_array_promote(node, name) ||
          cr_try_scalar_write(node, name) ||
          cr_try_native_array_alias(node, name) ||
          cr_try_boxed_array_write(node, name) ||
          cr_try_class_cast_write(node, name)
        return result if result
        # TI may have typed this local as Array(T), but since no native
        # construction path matched, the Crystal variable is actually RubyArray.
        @mctx.typed_array_locals.delete(name)
        old_suppress = @mctx.suppress_tuple_literals
        @mctx.suppress_tuple_literals = true
        cname = crystal_local(name)
        val = cr(node.value_node)
        @mctx.suppress_tuple_literals = old_suppress
        # Crystal can't reference a variable inside its own first assignment.
        @_declared_locals ||= Set.new
        needs_fwd = !@_declared_locals.include?(cname) && val.match?(/\b#{Regexp.escape(cname)}\b/)
        @_declared_locals << cname
        needs_fwd ? "#{cname} = RUBY_NIL; #{cname} = #{val}" : "#{cname} = #{val}"
      end

      # (0..n).to_a where TI says the result is Array[:i64] → native Crystal range to_a.
      def cr_try_range_to_a_write(node, name)
        elem = @mctx.local_array_elems[name] || @mctx.typed_array_locals[name]
        return unless elem&.raw?
        rhs = node.value_node
        return unless rhs.is_a?(Ast::MethodCall) && rhs.name == :to_a
        recv = rhs.receiver_node
        recv = recv.nodes.first while recv.is_a?(Ast::Sequence) && recv.nodes.size == 1
        return unless recv.is_a?(Ast::RangeLiteral)
        range_op = recv.exclusive ? "..." : ".."
        @mctx.native_array_locals[name] = elem
        "#{crystal_local(name)} = (#{coerce_i64(recv.begin_node)}#{range_op}#{coerce_i64(recv.end_node)}).to_a"
      end

      # Array.new(m) { Array.new(p, fill) } or Array.new(n) { [] } — nested native construction.
      def cr_try_nested_array_write(node, name)
        nat_elem = native_array_elem_type(name)
        return unless nat_elem.is_a?(Type) && nat_elem.array_like?
        rhs = node.value_node
        blk = rhs.is_a?(Ast::MethodCall) ? rhs.block_node : nil
        return unless blk.is_a?(Ast::Block)
        inner = blk.body
        inner = inner.nodes.first if inner.is_a?(Ast::Sequence) && inner.nodes.size == 1
        inner_crystal = nat_elem.to_crystal
        outer_args = rhs.arg_nodes || []
        if array_new_call?(inner)
          inner_args = inner.arg_nodes || []
          fill_str = raw_as(inner_args[1], nat_elem.elem)
          "#{crystal_local(name)} = Array(#{inner_crystal}).new(#{coerce_i64(outer_args[0])}) { #{inner_crystal}.new(#{coerce_i64(inner_args[0])}, #{fill_str}) }"
        elsif inner.is_a?(Ast::ArrayLiteral) && (inner.element_nodes || []).empty?
          "#{crystal_local(name)} = Array(#{inner_crystal}).new(#{coerce_i64(outer_args[0])}) { #{inner_crystal}.new }"
        end
      end

      # Array.new(n, fill) with TI-known element type → native Array(T) construction.
      def cr_try_typed_array_write(node, name)
        arr_ty = @mctx.typed_array_locals[name] or return
        rhs = node.value_node
        return unless array_new_call?(rhs)
        args = rhs.arg_nodes || []
        "#{crystal_local(name)} = Array(#{arr_ty.to_crystal}).new(#{coerce_i64(args[0])}, #{raw_as(args[1], arr_ty)})"
      end

      # Promote boxed-array local to native Array(T) from Array.new(n, default).
      def cr_try_boxed_array_promote(node, name)
        elem_ty = @mctx.local_array_elems[name] or return
        return if @mctx.typed_array_locals.key?(name)
        rhs = node.value_node
        return unless array_new_call?(rhs)
        args = rhs.arg_nodes || []
        return unless args.size == 2
        @mctx.native_array_locals[name] = elem_ty
        "#{crystal_local(name)} = Array(#{elem_ty.to_crystal}).new(#{coerce_i64(args[0])}, #{raw_as(args[1], elem_ty)})"
      end

      # s = native_array.dup → propagate native type
      def cr_try_native_dup_write(node, name)
        elem = @mctx.local_array_elems[name] || @mctx.typed_array_locals[name]
        return unless elem&.raw?
        rhs = node.value_node
        return unless rhs.is_a?(Ast::MethodCall) && (rhs.name == :dup || rhs.name == :clone)
        recv = rhs.receiver_node
        return unless recv.is_a?(Ast::LocalVariableRead)
        return unless native_array_elem_type(recv.name)
        @mctx.native_array_locals[name] = elem
        "#{crystal_local(name)} = #{crystal_local(recv.name)}.dup"
      end

      # Typed scalar local → emit raw value.
      def cr_try_scalar_write(node, name)
        raw_ty = @mctx.typed_locals[name] or return
        "#{crystal_local(name)} = #{raw_as(node.value_node, raw_ty)}"
      end

      # ci = c[i] where c is native nested array → emit bare, Crystal infers.
      def cr_try_native_array_alias(node, name)
        return unless @mctx.local_array_elems.key?(name) && native_array_elem_type(name)
        "#{crystal_local(name)} = #{cr(node.value_node)}"
      end

      # Boxed array local with known elem type → cast to RubyArray.
      def cr_try_boxed_array_write(node, name)
        return unless @mctx.local_array_elems.key?(name)
        old_suppress = @mctx.suppress_tuple_literals
        @mctx.suppress_tuple_literals = true
        rhs_str = cr(node.value_node)
        @mctx.suppress_tuple_literals = old_suppress
        cast = node.value_node.is_a?(Ast::ArrayLiteral) ? "" : ".as(RubyArray)"
        "#{crystal_local(name)} = #{rhs_str}#{cast}"
      end

      # Class-typed local → devirtualize cast.
      def cr_try_class_cast_write(node, name)
        cls_entry = @mctx.class_locals[name] or return
        @_declared_typed_locals ||= Set.new
        val = node.value_node
        nullable = cls_entry.is_a?(Array) && cls_entry[1] == :nullable
        anno = ""
        if !nullable && !@_declared_typed_locals.include?(name) && safe_for_type_annotation?(val)
          @_declared_typed_locals << name
          cls = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
          anno = " : #{crystal_class_name(cls)}"
        end
        "#{crystal_local(name)}#{anno} = #{cr(val)}"
      end

      def safe_for_type_annotation?(val)
        # Never annotate inside nested expressions (||=, &&=, begin blocks).
        # Crystal only allows type annotations at method/block body level.
        return false if @_inside_nested_expr
        case val
        when Ast::MethodCall
          val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
        when Ast::LocalVariableRead
          @_declared_typed_locals&.include?(val.name)
        when Ast::InstanceVariableRead
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

      def cr_array_literal(node)
        return super unless opt?(:tuple_literals) && !@mctx.suppress_tuple_literals
        elems = node.element_nodes || []
        return super unless elems.size >= 1 && elems.size <= MAX_TUPLE_SIZE &&
                            elems.none? { |e| e.is_a?(Ast::SplatArg) }
        if @mctx.emit_crystal_tuple
          # Return position: Crystal tuple preserves per-element types.
          parts = elems.map { |el| node_raw_type(el) ? raw(el) : cr(el) }
          "{#{parts.join(', ')}}"
        else
          "RubyTuple#{elems.size}.new(#{elems.map { |el| cr(el) }.join(', ')})"
        end
      end

      # Override: for typed ivars in boxed context, wrap in RubyFloat/RubyInteger.
      # In class methods (def self.foo), Crystal requires @@class_vars, not @ivars.
      def cr_ivar_read(node)
        ivt = @cctx.ivars[node.name]
        name = @mctx&.class_method ? node.name.to_s.sub('@', '@@') : node.name.to_s
        return "RubyFloat.new(#{name})" if ivt&.f64?
        return "RubyInteger.new(#{name})" if ivt&.i64?
        name
      end

      # Override: for typed ivars, coerce RHS to the raw type.
      # In class methods, use @@class_vars.
      def cr_ivar_write(node)
        iv_name = @mctx&.class_method ? node.name.to_s.sub('@', '@@') : node.name
        ty = @cctx.ivars[iv_name]
        if ty
          val = node.value_node
          # Array-typed ivars: @list = Array.new(n) → Array(Float64).new(n, 0.0)
          if ty&.array_like? && ty.elem&.raw? && val.is_a?(Ast::MethodCall) &&
             val.name == :new && val.receiver_node.is_a?(Ast::ConstantRead)
            crystal_ty = (ty) == Type::ARRAY_F64 ? "Float64" : "Int64"
            default = (ty) == Type::ARRAY_F64 ? "0.0" : "0"
            args = val.arg_nodes || []
            count = args.empty? ? "0" : coerce_i64(args[0])
            return "#{iv_name} = Array(#{crystal_ty}).new(#{count}, #{default})"
          end
          # Nil-safe coercion: untyped params may be nil (sentinel construction).
          if val.is_a?(Ast::LocalVariableRead) && !@mctx.typed_locals[val.name] && !node_raw_type(val)
            default = ty&.f64? ? "0.0_f64" : "0_i64"
            coerce = ty&.f64? ? ".to_f64" : ".to_i64"
            "#{iv_name} = ((_v = #{cr(val)}); _v.ruby_nil? ? #{default} : _v#{coerce})"
          else
            "#{iv_name} = #{raw_as(val, ty)}"
          end
        elsif @cctx.typed_ivars[iv_name]&.first == :class_or_nil
          val = node.value_node
          if val.is_a?(Ast::NilLiteral)
            "#{iv_name} = RUBY_NIL"
          else
            "#{iv_name} = #{cr(val)}"
          end
        else
          "#{iv_name} = #{cr(node.value_node)}"
        end
      end

      # Override: for index op-write (ci[j] += ...) with a raw-typed index,
      # emit the index temp as bare Int64 so the Int64 array overload is used.
      def cr_index_op_write(node)
        idx = node.index_arg_nodes&.first
        op = node.operator
        recv_node = node.receiver_node
        val_node = node.value_node
        # Native Array(T) receiver: emit arr[i] op= val directly, coercing index to Int64
        recv_name = recv_node.is_a?(Ast::LocalVariableRead) && recv_node.name
        if recv_name && (nat_ty = native_array_elem_type(recv_name))
          return "#{crystal_local(recv_name)}[#{coerce_i64(idx)}] #{op}= #{raw_as(val_node, nat_ty)}"
        end
        return super unless idx && node_raw_type(idx)
        r = "_iopw_r#{@temp_counter}"
        i = "_iopw_i#{@temp_counter}"
        @temp_counter += 1
        recv_str = recv_node ? cr(recv_node) : "self"
        recv_elem_ty = recv_node.is_a?(Ast::LocalVariableRead) &&
                       @mctx.local_array_elems[recv_node.name]
        if recv_elem_ty
          unbox = recv_elem_ty&.f64? ? ".as(RubyFloat).to_f64" : ".as(RubyInteger).to_i64"
          box = recv_elem_ty&.f64? ? "RubyFloat" : "RubyInteger"
          "(#{r} = #{recv_str}; #{i} = #{raw(idx)}; #{r}[#{i}] = #{box}.new(#{r}[#{i}]#{unbox} #{op} #{raw_as(val_node, recv_elem_ty)}))"
        else
          "(#{r} = #{recv_str}; #{i} = #{raw(idx)}; #{r}[#{i}] = (#{r}[#{i}] #{op} #{cr(val_node)}))"
        end
      end

      # Call args where each arg is coerced to its declared raw type
      # (if Int64/Float64) or boxed (otherwise). Returns Crystal source.
      def cr_typed_call_args(args, param_types)
        parts = args.each_with_index.map do |arg, i|
          pt = param_types[i]
          pt&.raw? ? raw_as(arg, pt) : cr(arg)
        end
        "(#{parts.join(', ')})"
      end

      # Box a value guaranteed to be RubyObject — wrap raw Int64/Float64 in
      # RubyInteger/RubyFloat. Returns Crystal source.
      def cr_boxed(node)
        vt = node_raw_type(node)
        return "RubyInteger.new(#{raw(node)})" if vt&.i64?
        return "RubyFloat.new(#{raw(node)})" if vt&.f64?
        cr(node)
      end

      # Block suffix after typed call args (cr_call_args handles its own block).
      def cr_block_if_present(node)
        blk = node.block_node
        return "" unless blk && !blk.is_a?(Ast::BlockArg)
        " #{cr_block(blk)}"
      end


      def cr_method_call(node)
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
          cr_try_raw_arithmetic(node) ||
          default_method_call(node)
      end

      # @list.fetch(i) or @list[i] on native array ivar → box result for RubyObject context
      def cr_try_ivar_array_access(node)
        recv = node.receiver_node
        return unless recv.is_a?(Ast::InstanceVariableRead)
        iv_ty = @cctx&.ivars&.dig(recv.name)
        return unless iv_ty&.array_like? && iv_ty.elem&.raw?
        args = node.arg_nodes || []
        return unless (node.name == :fetch || node.name == :[]) && args.size == 1
        box = (iv_ty) == Type::ARRAY_F64 ? "RubyFloat" : "RubyInteger"
        "#{box}.new(#{recv.name}[#{coerce_i64(args[0])}])"
      end

      # Constant-fold respond_to?(:literal) and is_a?/kind_of?(Constant) when
      # receiver type is known from TI devirtualization.
      def cr_try_constant_fold(node)
        return unless node.receiver_node && (recv_class = receiver_known_class(node.receiver_node))
        klass = lookup_vm_class(recv_class) or return
        if node.name == :respond_to? && node.arg_nodes&.size&.between?(1, 2) &&
           node.arg_nodes[0].is_a?(Ast::SymbolLiteral)
          klass.lookup_method(node.arg_nodes[0].value) ? "RUBY_TRUE" : "RUBY_FALSE"
        elsif (node.name == :is_a? || node.name == :kind_of?) &&
              node.arg_nodes&.size == 1 && node.arg_nodes[0].is_a?(Ast::ConstantRead)
          target = lookup_vm_class(node.arg_nodes[0].name) or return
          klass.ancestors_include?(target) ? "RUBY_TRUE" : "RUBY_FALSE"
        end
      end

      # Array.new(n) { |i| body } with all-integer block params → native Int64 iteration.
      def cr_try_native_array_new(node)
        return unless node.name == :new && node.receiver_node.is_a?(Ast::ConstantRead) &&
                      node.receiver_node.name == :Array && node.block_node.is_a?(Ast::Block)
        blk = node.block_node
        params = blk.required_params || []
        args = node.arg_nodes || []
        return unless !params.empty? && args.size == 1 && node_raw_type(args[0])&.i64? &&
                      params.all? { |p| p.is_a?(Symbol) && @mctx.block_params[p]&.i64? }
        indent_str = "  " * @indent
        old_rbp = @mctx.raw_block_params
        @mctx.raw_block_params = old_rbp.merge(params.map { |p| [p, Type::I64] }.to_h)
        body_lines = nil
        indented { body_lines = native_block_body_lines(blk.body) }
        @mctx.raw_block_params = old_rbp
        body_str = body_lines.map { |l| "#{'  ' * (@indent + 1)}#{l}" }.join("\n")
        "RubyArray.new(#{raw(args[0])}) { |#{params.map { |p| crystal_local(p) }.join(', ')}|\n#{body_str}\n#{indent_str}}"
      end

      # n.times/upto/downto { block } when n is raw i64 → Crystal native iteration.
      def cr_try_native_iteration(node)
        return unless opt?(:native_iteration) && node.block_node &&
                      !node.block_node.is_a?(Ast::BlockArg) &&
                      (node.arg_nodes || []).size <= 1 && node_raw_type(node.receiver_node)&.i64?
        case node.name
        when :times
          "#{raw(node.receiver_node)}.times #{cr_native_iter_block(node.block_node)}"
        when :upto
          limit = (node.arg_nodes || [])[0]
          return unless limit && node_raw_type(limit)&.i64?
          "(#{raw(node.receiver_node)}..#{raw(limit)}).each #{cr_native_iter_block(node.block_node)}"
        when :downto
          limit = (node.arg_nodes || [])[0]
          return unless limit && node_raw_type(limit)&.i64?
          "(#{raw(limit)}..#{raw(node.receiver_node)}).reverse_each #{cr_native_iter_block(node.block_node)}"
        end
      end

      # Typed instance method call on a class-typed receiver → emit args with declared types.
      def cr_try_typed_instance_call(node)
        return unless node.receiver_node.is_a?(Ast::LocalVariableRead)
        cls_entry = @mctx.class_locals[node.receiver_node.name] or return
        recv_class = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
        tp = @gctx.class_params[[recv_class, node.name]] or return
        "#{cr(node.receiver_node)}.#{crystal_method_name(node.name)}#{cr_typed_call_args(node.arg_nodes || [], tp)}#{cr_block_if_present(node)}"
      end

      # Method call on native array local → emit raw args (Crystal Array methods expect Int, not RubyInteger)
      def cr_try_native_array_method(node)
        return unless node.receiver_node&.is_a?(Ast::LocalVariableRead)
        recv_name = node.receiver_node.name
        return unless native_array_elem_type(recv_name)
        return unless %i[delete_at insert push unshift].include?(node.name)
        args = (node.arg_nodes || []).map { |arg| node_raw_type(arg) ? raw(arg) : cr(arg) }
        "#{crystal_local(recv_name)}.#{crystal_method_name(node.name)}(#{args.join(', ')})"
      end

      # arr << val on native arrays → array push (not integer shift).
      def cr_try_array_push(node)
        return unless node.name == :<< && node.receiver_node && node.arg_nodes&.size == 1
        recv = node.receiver_node
        if recv.is_a?(Ast::LocalVariableRead) && (elem = native_array_elem_type(recv.name))
          "#{cr(recv)} << #{raw_as(node.arg_nodes[0], elem)}"
        elsif recv.is_a?(Ast::MethodCall) && recv.name == :[] &&
              recv.receiver_node.is_a?(Ast::LocalVariableRead)
          arr_elem = native_array_elem_type(recv.receiver_node.name)
          return unless arr_elem.is_a?(Type) && arr_elem.array_like?
          "#{cr(recv)} << #{raw_as(node.arg_nodes[0], arr_elem.elem)}"
        end
      end

      # mc[i] where mc is Array(Array(T)) → coerce index, no boxing.
      def cr_try_native_array_read(node)
        return unless node.name == :[] && node.arg_nodes&.size == 1 &&
                      node.receiver_node&.is_a?(Ast::LocalVariableRead)
        recv_elem = native_array_elem_type(node.receiver_node.name)
        return unless recv_elem.is_a?(Type) && recv_elem.array_like?
        "#{crystal_local(node.receiver_node.name)}[#{coerce_i64(node.arg_nodes[0])}]"
      end

      # a[k] where a is native Array(T) in boxed context → box the element.
      def cr_try_boxed_array_read(node)
        return unless node.name == :[] && node.arg_nodes&.size == 1 &&
                      node.receiver_node&.is_a?(Ast::LocalVariableRead)
        arr_ty = native_array_elem_type(node.receiver_node.name) or return
        box_fn = arr_ty&.f64? ? "RubyFloat" : "RubyInteger"
        "#{box_fn}.new(#{crystal_local(node.receiver_node.name)}[#{coerce_i64(node.arg_nodes[0])}])"
      end

      # a[k] with raw index on known array/tuple receivers → use Int64 overload.
      def cr_try_raw_index_read(node)
        return unless node.name == :[] && node.arg_nodes&.size == 1 && node_raw_type(node.arg_nodes[0])
        "#{cr(node.receiver_node)}[#{raw(node.arg_nodes[0])}]"
      end

      # Free call to fully-specialized method with all-raw args → raw Int64 overload.
      def cr_try_specialized_free_call(node)
        return unless node.receiver_node.nil? && @gctx.typed_method_returns[node.name]
        tp = @gctx.typed_params[node.name] or return
        args = node.arg_nodes || []
        return unless args.size == tp.size && args.all? { |a| node_raw_type(a) }
        "#{crystal_method_name(node.name)}(#{args.map { |a| raw(a) }.join(', ')})"
      end

      # Free call inside class → dispatch to eigenclass method (self.x).
      def cr_try_eigen_dispatch(node)
        return unless node.receiver_node.nil? && @cctx.eigen_methods&.include?(node.name)
        prefix = "self.#{crystal_method_name(node.name)}"
        if !@mctx.suppress_typed_call_args && (opt?(:call_site_types) || opt?(:method_specialization))
          tp = @gctx.inferred_params[node.name] || @gctx.class_params[[@cctx.name, node.name]]
          can_use_typed = tp&.any? { |t| t && t != :ruby_object } &&
            tp.all? { |pt| !pt || !pt.native? || pt.raw? }
          if can_use_typed
            return "#{prefix}#{cr_typed_call_args(node.arg_nodes || [], tp)}#{cr_block_if_present(node)}"
          end
        end
        "#{prefix}#{cr_call_args(node)}"
      end

      # Free call with inferred param types → coerce args.
      def cr_try_typed_free_call(node)
        return unless !@mctx.suppress_typed_call_args && node.receiver_node.nil?
        tp = @gctx.inferred_params[node.name] or return
        return unless tp.all? { |t| t&.native? } || @gctx.typed_params[node.name]
        "#{crystal_method_name(node.name)}#{cr_typed_call_args(node.arg_nodes || [], tp)}#{cr_block_if_present(node)}"
      end

      # Devirtualize: cast class-typed receiver for static dispatch.
      def cr_try_devirtualized_call(node)
        return unless node.receiver_node.is_a?(Ast::LocalVariableRead)
        cls_entry = @mctx.class_locals[node.receiver_node.name] or return
        cls = cls_entry.is_a?(Array) ? cls_entry[0] : cls_entry
        "#{crystal_local(node.receiver_node.name)}.as(#{crystal_class_name(cls)}).#{crystal_method_name(node.name)}#{cr_call_args(node)}"
      end

      # Both operands raw-typed → Crystal arithmetic/comparison, skip RubyObject dispatch.
      def cr_try_raw_arithmetic(node)
        return unless node.receiver_node && (node.arg_nodes || []).size == 1 &&
                      (ARITH_OPS_UNBOX | CrystalEmitter::COMPARE_OPS).include?(node.name)
        rt = node_raw_type(node.receiver_node)
        at = node_raw_type(node.arg_nodes[0])
        return unless rt && at
        ty = (rt&.f64? || at&.f64?) ? Type::F64 : Type::I64
        op = (node.name == :/ && ty.i64?) ? "//" : node.name.to_s
        recv_str = raw_as(node.receiver_node, ty)
        arg_str = raw_as(node.arg_nodes[0], ty)
        if CrystalEmitter::COMPARE_OPS.include?(node.name)
          "((#{recv_str} #{op} #{arg_str}) ? RUBY_TRUE : RUBY_FALSE)"
        else
          "#{ty.i64? ? 'RubyInteger.new(' : 'RubyFloat.new('}#{recv_str} #{op} #{arg_str})"
        end
      end

      # Override: emit typed local args as raw in method calls.
      # Crystal's overload resolution picks Int64/Float64 overloads where
      # available, and *args stubs accept any type.
      def cr_call_args(node)
        return super unless opt?(:unbox_locals)
        return super if node.name == :new
        args = node.arg_nodes
        kw_args = node.kw_arg_nodes
        return "" if args.empty? && kw_args.empty? && node.block_node.nil?

        # Per-arg typed dispatch: if the callee has inferred raw param types,
        # pass each raw-typed arg via raw_as so it matches the typed overload
        # without boxing. Mixed raw + non-raw args work because the typed
        # overload uses RubyObject for the non-raw positions.
        callee_inferred = node.receiver_node.nil? ? @gctx.inferred_params[node.name] : nil
        if callee_inferred && callee_inferred.any? { |t| t&.raw? } && args.size == callee_inferred.size
          parts = args.each_with_index.map do |arg, i|
            pt = callee_inferred[i]
            pt&.raw? ? raw_as(arg, pt) : cr(arg)
          end
          parts += kw_args.map do |kw_name, val_node|
            key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
            "#{key}: #{cr(val_node)}"
          end
          s = "(#{parts.join(', ')})"
          if node.block_node
            s += " "
            s += node.block_node.is_a?(Ast::BlockArg) ? cr_block_arg(node.block_node) : cr_block(node.block_node)
          end
          return s
        end

        all_raw = args.all? { |a| a.is_a?(Ast::SplatArg) || raw_passable_arg?(a) }
        has_typed_overload = @gctx.typed_params&.key?(node.name) ||
          (@cctx&.name && @gctx.class_params&.key?([@cctx.name, node.name])) ||
          (node.receiver_node.is_a?(Ast::ConstantRead) && @gctx.class_params&.key?([node.receiver_node.name, node.name]))
        return super unless all_raw && has_typed_overload

        parts = args.map do |arg|
          if arg.is_a?(Ast::SplatArg)
            "RUBY_NIL"
          elsif raw_passable_arg?(arg)
            raw(arg)
          else
            cr(arg)
          end
        end
        parts += kw_args.map do |kw_name, val_node|
          key = kw_name.is_a?(Ast::SymbolLiteral) ? kw_name.value : kw_name
          "#{key}: #{cr(val_node)}"
        end
        s = "(#{parts.join(', ')})"
        if node.block_node
          s += " "
          s += node.block_node.is_a?(Ast::BlockArg) ? cr_block_arg(node.block_node) : cr_block(node.block_node)
        end
        s
      end

      # Override: for []= with typed array or raw-typed index, emit accordingly.
      def cr_attribute_write(node)
        recv = node.receiver_node
        args = node.arg_nodes
        # Setter call on class-typed local receiver (e.g. current.left = X):
        # cast to the non-nullable concrete class so typed setter overloads
        # dispatch correctly.
        if node.name != :[]= && recv.is_a?(Ast::LocalVariableRead) &&
           (cls_entry = @mctx.class_locals[recv.name])
          setter = node.name.to_s.chomp('=')
          if cls_entry.is_a?(Array)
            # Nullable: cast to concrete class for typed setter dispatch
            return "#{crystal_local(recv.name)}.as(#{crystal_class_name(cls_entry[0])}).#{setter} = #{cr(args[0])}"
          end
          # Non-nullable: local is already concrete class, no cast needed
          return "#{crystal_local(recv.name)}.#{setter} = #{cr(args[0])}"
        end
        return super unless node.name == :[]=
        # Ivar array write: @list[i] = val where @list is Array(Float64)
        if recv.is_a?(Ast::InstanceVariableRead) && args&.size == 2
          iv_ty = @cctx&.ivars&.dig(recv.name)
          if iv_ty&.array_like? && iv_ty.elem&.raw?
            val_str = (iv_ty) == Type::ARRAY_F64 ? coerce_f64(args[1]) : coerce_i64(args[1])
            return "#{recv.name}[#{coerce_i64(args[0])}] = #{val_str}"
          end
        end
        # Unboxed/native Array(T) write: emit value as bare native type
        if recv.is_a?(Ast::LocalVariableRead) &&
           (arr_ty = native_array_elem_type(recv.name)) && args&.size == 2
          recv_name = recv.name
          if args[0].is_a?(Ast::RangeLiteral)
            range_op = args[0].exclusive ? "..." : ".."
            return "#{crystal_local(recv_name)}[#{coerce_i64(args[0].begin_node)}#{range_op}#{coerce_i64(args[0].end_node)}] = #{cr(args[1])}"
          else
            return "#{crystal_local(recv_name)}[#{coerce_i64(args[0])}] = #{raw_as(args[1], arr_ty)}"
          end
        end
        # Boxed RubyArray with known elem type: box raw value on write
        if recv.is_a?(Ast::LocalVariableRead) &&
           (elem_ty = @mctx.local_array_elems[recv.name]) &&
           args&.size == 2 && node_raw_type(args[1])
          box = elem_ty&.f64? ? "RubyFloat" : "RubyInteger"
          return "#{cr(recv)}[#{coerce_i64(args[0])}] = #{box}.new(#{raw(args[1])})"
        end
        # Non-typed array with raw-typed index: use Int64 overload
        if node_raw_type(args&.first)
          val = args[1]
          vt = node_raw_type(val)
          val_str = if vt&.i64? then "RubyInteger.new(#{raw(val)})"
                    elsif vt&.f64? then "RubyFloat.new(#{raw(val)})"
                    else cr(val)
                    end
          return "#{cr(recv)}[#{raw(args[0])}] = #{val_str}"
        end
        default_attribute_write(node)
      end

      # Override: for comparisons with at least one raw-typed operand, use bare
      # Crystal comparison with .to_i64/.to_f64 coercion on the untyped side.
      def cr_truthy(node)
        return cr_crystal_bool(node) if crystal_bool_emittable?(node)
        if opt?(:condition_simplify) && comparison_op_call?(node)
          recv = node.receiver_node
          arg = node.arg_nodes[0]
          rt = node_raw_type(recv)
          at = node_raw_type(arg)
          if rt && at
            ty = (rt&.f64? || at&.f64?) ? Type::F64 : Type::I64
            recv_str = ty.i64? ? coerce_i64(recv) : coerce_f64(recv)
            arg_str = ty.i64? ? coerce_i64(arg) : coerce_f64(arg)
            return "(#{recv_str} #{node.name} #{arg_str})"
          end
        end
        case node
        when Ast::TrueLiteral then "true"
        when Ast::FalseLiteral, Ast::NilLiteral then "false"
        else
          if boolean_valued?(node) then cr(node)
          else "(#{cr(node)}).truthy?"
          end
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
        node.is_a?(Ast::MethodCall) &&
          COMPARE_OPS.include?(node.name) &&
          node.receiver_node &&
          node.arg_nodes&.size == 1 &&
          !user_overrides_comparison?(node.name)
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
      def cr_multiple_assignment(node)
        targets = node.targets
        rhs = node.value_node
        has_splat = targets.any? { |t| t[0].to_s.end_with?('_splat') || t[0] == :splat_nil }

        # Typed multi-return: RHS is a call to a user method that returns a Crystal tuple.
        if !has_splat && rhs.is_a?(Ast::MethodCall) && rhs.receiver_node.nil?
          method_name = rhs.name
          method = @cc.top_level_scope.methods_table&.fetch(method_name, nil)
          if method.is_a?(Vm::Method) && returns_array_literal?(method.body)
            tmp_names = targets.each_with_index.map { |_, i| "_tup#{@temp_counter}_#{i}" }
            @temp_counter += 1
            indent_str = "  " * @indent
            lines = ["#{tmp_names.join(', ')} = #{cr(rhs)}"]
            targets.each_with_index { |t, i| lines << cr_masgn_assign(t, tmp_names[i]) }
            return lines.join("\n#{indent_str}")
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
            indent_str = "  " * @indent
            lines = []
            targets.each_with_index do |t, i|
              name = t[1]
              elem = elems[i]
              if (raw_ty = @mctx.typed_locals[name])
                lines << "#{crystal_local(name)} = #{raw_as(elem, raw_ty)}"
              elsif (cls = @mctx.class_locals[name])
                lines << "#{crystal_local(name)} = #{cr(elem)}.as(#{crystal_class_name(cls)})"
              else
                # typed array local — fall back to default for this case
                return default_multiple_assignment(node)
              end
            end
            return lines.join("\n#{indent_str}")
          end
        end

        default_multiple_assignment(node)
      end

      def cr_masgn_assign(target, value_code)
        if target[0] == :ivar && (ty = @cctx.ivars[target[1]])
          "#{target[1]} = #{value_code}#{ty&.f64? ? '.to_f64' : '.to_i64'}"
        elsif (target[0] == :local || target[0] == :local_splat) &&
              (ty = @mctx.typed_locals[target[1]])
          "#{crystal_local(target[1])} = #{value_code}#{ty&.f64? ? '.to_f64' : '.to_i64'}"
        elsif (target[0] == :index || target[0] == :index_splat) &&
              target[1].is_a?(Ast::LocalVariableRead) &&
              (nat_ty = native_array_elem_type(target[1].name))
          coerce = nat_ty&.f64? ? ".to_f64" : ".to_i64"
          idxs = target[2].map { |idx| coerce_i64(idx) }.join(", ")
          "#{crystal_local(target[1].name)}[#{idxs}] = #{value_code}#{coerce}"
        else
          default_masgn_assign(target, value_code)
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
          ivt = @cctx.ivars[iv]
          if ivt&.f64?
            line "def #{crystal_method_name(mname)} : RubyObject; RubyFloat.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Float64; #{iv}; end"
          elsif ivt&.i64?
            line "def #{crystal_method_name(mname)} : RubyObject; RubyInteger.new(#{iv}); end"
            line "def #{crystal_method_name(mname)}_raw : Int64; #{iv}; end"
          else
            ct = @cctx.typed_ivars[iv]
            if ct
              kind, cls = ct
              crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[cls] || "Ruby_#{crystal_constant(cls)}"
              ret_type = (kind == :class_or_nil && cls == @cctx.name) ? "#{crystal_cls} | RubyNil" : crystal_cls
              line "def #{crystal_method_name(mname)} : #{ret_type}; #{iv}; end"
            else
              line "def #{crystal_method_name(mname)} : RubyObject; #{iv}; end"
            end
          end
        when Ast::InstanceVariableWrite
          iv = body.name
          ivt = @cctx.ivars[iv]
          if ivt&.f64?
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_f64; v; end"
          elsif ivt&.i64?
            line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.to_i64; v; end"
          else
            ct = @cctx.typed_ivars[iv]
            if ct && ct[0] == :class_or_nil && ct[1] == @cctx.name
              crystal_cls = CrystalEmitter::RUBY_TO_CRYSTAL_TYPE[ct[1]] || "Ruby_#{crystal_constant(ct[1])}"
              # Self-referential nullable ivar stored as Ruby_X | RubyNil. The
              # union accepts both branches; one overload covers both via
              # RubyObject (which subsumes Ruby_X and RubyNil).
              line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v.as(#{crystal_cls} | RubyNil); v; end"
            else
              line "def #{crystal_method_name(mname)}(v : RubyObject) : RubyObject; #{iv} = v; end"
            end
          end
        end
      end
    end
  end
end
