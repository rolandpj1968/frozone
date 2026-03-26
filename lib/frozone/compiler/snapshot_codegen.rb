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
        NilClass TrueClass FalseClass Binding Struct Data Enumerator Complex Rational
        TOPLEVEL_BINDING ENV ARGV
      ].to_set

      # Generate Crystal source from the settled VM snapshot.
      #
      # @param execute_block [Ast::Block, nil]  the block passed to Frozone.compile!
      # @param top_level_scope [Vm::ClassObject] Core::OBJECT_CLASS
      # @param globals [Hash] Vm::GLOBALS
      def generate(execute_block:, top_level_scope:, globals:, stub_file: nil)
        @top_level_scope = top_level_scope
        @stub_file       = stub_file

        # Pre-pass: collect user method names for RubyObject stubs
        collect_user_methods_from_scope(top_level_scope)
        collect_user_methods_from_block(execute_block)

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

        scope.instance_variable_get(:@methods_table)&.each do |name, method|
          next unless method.is_a?(Vm::Method)
          next unless user_source_location?(method.source_location)
          @user_methods << name
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
          m.is_a?(Vm::Method) && user_source_location?(m.source_location)
        end
        return if user_methods.nil? || user_methods.empty?

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
          user_methods.each do |mname, method|
            emit_indent
            emit_vm_method(mname, method)
            emit_newline
            emit_newline
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
          emit_vm_method(name, method)
          emit_newline
          emit_newline
        end
      end

      # Emit a Crystal method definition from a Vm::Method object.
      # Vm::Method has the same ivar names as Ast::MethodDef, so we can pass
      # it directly to emit_param_list (which uses ivar/instance_variable_get).
      def emit_vm_method(name, method)
        string_return = STRING_RETURN_METHODS.include?(name)
        crystal_name  = string_return ? name.to_s : crystal_method_name(name)

        write "def #{crystal_name}"
        write " : String" if string_return
        emit_param_list(method)   # duck-types on Vm::Method — same ivars as Ast::MethodDef
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
    end
  end
end
