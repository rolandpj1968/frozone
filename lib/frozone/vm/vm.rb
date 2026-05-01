require_relative 'core'
require_relative 'globals'
require_relative 'proc_object'

require_relative 'parser'

require_relative 'context'
require_relative 'frame'
require_relative 'method'

require_relative 'binding_object'
require_relative 'fiber_object'
require_relative 'unbound_method_object'
require_relative 'bound_method_object'
require_relative 'io_object'
require_relative 'encoding_converter_object'
require_relative 'nil_object'
require_relative 'range_object'
require_relative 'float_object'
require_relative 'time_object'
require_relative 'regexp_object'
require_relative 'random_object'
require_relative 'match_data_object'
require_relative 'process_status_object'
require_relative '../compiler/module_erasure'

module Frozone
  module Vm
    ParseResult = Struct.new(:ast, :top_level_locals, :prism_always_warnings, :prism_verbose_warnings)

    class Vm
      # TODO - the most recent docs as of time of writing
      #   https://docs.ruby-lang.org/en/4.0/
      FROZONE_CORE_VERSION = "4.0"

      # Evaluate a Ruby snippet and return the resulting VM object.
      def eval_snippet(code, dump_ast = false) = evaluate(code, dump_ast, filepath: "-e")

      def initialize(options = {})
        @options = options
      end

      def run
        load_core

        ruby_version = StringObject.new('4.0.1')
        ruby_platform = StringObject.new(RUBY_PLATFORM)
        ruby_engine = StringObject.new('ruby')
        ruby_eng_version = StringObject.new('4.0.1')
        ruby_patchlevel = IntegerObject.new(0)
        ruby_revision = StringObject.new('0')
        ruby_release = StringObject.new('2025-01-01')
        ruby_description = StringObject.new("frozone 4.0.1 (#{RUBY_PLATFORM})")
        ruby_copyright = StringObject.new('frozone - Copyright (C) 2024 frozone')
        Core::OBJECT_CLASS.set_constant(:RUBY_VERSION,        ruby_version)
        Core::OBJECT_CLASS.set_constant(:RUBY_PLATFORM,       ruby_platform)
        Core::OBJECT_CLASS.set_constant(:RUBY_ENGINE,         ruby_engine)
        Core::OBJECT_CLASS.set_constant(:RUBY_ENGINE_VERSION, ruby_eng_version)
        Core::OBJECT_CLASS.set_constant(:RUBY_PATCHLEVEL,     ruby_patchlevel)
        Core::OBJECT_CLASS.set_constant(:RUBY_REVISION,       ruby_revision)
        Core::OBJECT_CLASS.set_constant(:RUBY_RELEASE_DATE,   ruby_release)
        Core::OBJECT_CLASS.set_constant(:RUBY_DESCRIPTION,    ruby_description)
        Core::OBJECT_CLASS.set_constant(:RUBY_NAME,           StringObject.new('ruby'))
        Core::OBJECT_CLASS.set_constant(:RUBY_COPYRIGHT,      ruby_copyright)
        Core::OBJECT_CLASS.set_constant(:RUBY_EXE,            StringObject.new(RbConfig.ruby))

        ruby_mod = ModuleObject.new(:Ruby, Core::OBJECT_CLASS)
        ruby_mod.set_constant(:VERSION,        ruby_version)
        ruby_mod.set_constant(:PLATFORM,       ruby_platform)
        ruby_mod.set_constant(:ENGINE,         ruby_engine)
        ruby_mod.set_constant(:ENGINE_VERSION, ruby_eng_version)
        ruby_mod.set_constant(:PATCHLEVEL,     ruby_patchlevel)
        ruby_mod.set_constant(:REVISION,       ruby_revision)
        ruby_mod.set_constant(:RELEASE_DATE,   ruby_release)
        ruby_mod.set_constant(:DESCRIPTION,    ruby_description)
        ruby_mod.set_constant(:COPYRIGHT,      ruby_copyright)
        Core::OBJECT_CLASS.set_constant(:Ruby, ruby_mod)

        float_class = Core::OBJECT_CLASS.get_constant(:Float)
        float_class.set_constant(:INFINITY, FloatObject.new(::Float::INFINITY))
        float_class.set_constant(:NAN,      FloatObject.new(::Float::NAN))

        Core::OBJECT_CLASS.set_constant(:STDOUT, GLOBALS[:"$stdout"])
        Core::OBJECT_CLASS.set_constant(:STDERR, GLOBALS[:"$stderr"])
        Core::OBJECT_CLASS.set_constant(:STDIN,  GLOBALS[:"$stdin"])

        Core::OBJECT_CLASS.set_constant(:TOPLEVEL_BINDING, NilObject::NIL)
        Core::OBJECT_CLASS.set_constant(:ARGF, GLOBALS[:"$<"] || NilObject::NIL)

        script_argv = @options[:argv][1..] || []
        argv_obj = ArrayObject.new(script_argv.map { |a| StringObject.new(a) })
        Core::OBJECT_CLASS.set_constant(:ARGV, argv_obj)
        GLOBALS[:"$*"] = argv_obj

        scripts = @options[:scripts]

        # Signal that the real main evaluation is starting (not core-library loading).
        # Used in `evaluate` to set TOPLEVEL_BINDING only once for the main script.
        @in_main_eval = true

        # Pre-load -r/--require files before the main script.
        (@options[:requires] || []).each do |req_path|
          evaluate_file(File.expand_path(req_path))
        end

        # if -e is present then ruby DOES NOT evaluate an ARGV file
        # Note: ruby -e 'ARGV.each {|f| load f}' file1.rb file2.rb file3.rb
        begin
          if @options[:aot]
            file = @options[:argv][0]
            raise "frozone --aot requires a file argument" unless file
            aot_compile(File.expand_path(file))
          elsif @options[:flatten]
            file = @options[:argv][0]
            raise "frozone --flatten requires a file argument" unless file
            flatten_and_run(File.expand_path(file))
          elsif scripts.empty?
            # if -e is absent then ruby evaluates the FIRST file only
            file = @options[:argv][0]
            file.nil? ? eval_snippet("") : evaluate_file(File.expand_path(file))
          else
            # if multiple -e scripts are present, ruby simply joins them with \n, and parses together
            #   ruby -e 'puts 3; class A' -e 'end; puts 4'
            #   ruby -e 'puts "ha' -e 'llo"'
            #   ruby -e 'puts 3' -e '@%@#$%@'
            eval_snippet(scripts.join("\n"))
          end
        rescue FrozoneException => e
          vm_obj = e.vm_object
          if vm_obj.is_a?(ObjectObject)
            cls = vm_obj.class_object
            while cls
              if cls.name == :SystemExit
                status_obj = vm_obj.get_ivar(:@status)
                exit(status_obj.is_a?(IntegerObject) ? status_obj.raw : 0)
              end
              if cls.name == :SignalException || cls.name == :Interrupt
                signo_obj = vm_obj.get_ivar(:@signo)
                signo = signo_obj.is_a?(IntegerObject) ? signo_obj.raw : nil
                if signo
                  Signal.trap(signo, "DEFAULT") rescue nil
                  ::Process.kill(signo, ::Process.pid) rescue nil
                  sleep  # wait for the signal to kill us
                end
                exit(1)
              end
              cls = cls.superclass
            end
            # Print unhandled exception in MRI format to stderr
            print_unhandled_exception(vm_obj)
            exit(1)
          end
          raise
        end
      end

      # Print an unhandled exception in MRI format to $stderr.
      # MRI format: backtrace entries already contain "in 'method'", so:
      #   path:line:in 'method': message (ClassName)
      #   \tfrom path:line:in 'method'
      #   ...
      # Causes are appended (main exception first, then its cause, recursively).
      def print_unhandled_exception(vm_obj)
        print_exception_with_backtrace(vm_obj)
        # Append cause chain after (MRI prints cause after main exception)
        seen = { vm_obj.__id__ => true }
        cause_obj = vm_obj.get_ivar(:@cause)
        while cause_obj.is_a?(ObjectObject) && !cause_obj.is_a?(NilObject) && !seen[cause_obj.__id__]
          seen[cause_obj.__id__] = true
          print_exception_with_backtrace(cause_obj)
          cause_obj = cause_obj.get_ivar(:@cause)
        end
      end

      def print_exception_with_backtrace(vm_obj)
        cls_name = vm_obj.class_object&.full_name || "Exception"
        msg_obj = vm_obj.get_ivar(:@message)
        msg = msg_obj.is_a?(StringObject) ? msg_obj.raw : cls_name
        bt_obj = vm_obj.get_ivar(:@backtrace)
        bt = bt_obj.is_a?(ArrayObject) ? bt_obj.raw.map { |e| e.is_a?(StringObject) ? e.raw : e.to_s } : []
        if bt.empty?
          $stderr.puts "#{msg} (#{cls_name})"
        else
          $stderr.puts "#{bt[0]}: #{msg} (#{cls_name})"
          bt[1..].each { |line| $stderr.puts "\tfrom #{line}" }
        end
      end

      # Load the standard library into the shared class hierarchy.
      # Idempotent: safe to call multiple times (methods are simply redefined).
      #
      # Load order matters for a few bootstrap reasons:
      #
      #   1. module.rb MUST be first: it defines Module#include, Module#attr_reader,
      #      Module#module_function, etc. Every subsequent file that calls `include`,
      #      `attr_accessor`, or `module_function` in its class/module body depends on
      #      these being available as dispatchable methods on the class being opened.
      #      (core.rb has already created the essential VM-level ClassObjects, but has
      #      not yet given Module any ruby-land methods.)
      #
      #   2. kernel.rb before object.rb: object.rb says `class Object < BasicObject;
      #      include Kernel`, so Kernel must exist first.
      #
      #   3. comparable.rb + enumerable.rb before the classes that include them
      #      (numeric.rb → integer/float, string, symbol, array, hash, range).
      #
      #   4. exception.rb before encoding/io/thread: those files add subclasses and
      #      methods that reference exception classes.
      #
      # Everything else is natural ruby-land; no special hierarchy.rb bootstrap file
      # is needed.
      def load_core
        core_path = File.expand_path("../../core/#{FROZONE_CORE_VERSION}", __dir__)
        evaluate_file("#{core_path}/module.rb")
        ObjectObject.end_bootstrap!
        evaluate_file("#{core_path}/class.rb")
        evaluate_file("#{core_path}/refinement.rb")
        evaluate_file("#{core_path}/basic_object.rb")
        evaluate_file("#{core_path}/kernel.rb")
        evaluate_file("#{core_path}/object.rb")
        evaluate_file("#{core_path}/warning.rb")
        evaluate_file("#{core_path}/comparable.rb")
        evaluate_file("#{core_path}/enumerable.rb")
        evaluate_file("#{core_path}/numeric.rb")
        evaluate_file("#{core_path}/nil_class.rb")
        evaluate_file("#{core_path}/true_class.rb")
        evaluate_file("#{core_path}/false_class.rb")
        evaluate_file("#{core_path}/integer.rb")
        evaluate_file("#{core_path}/float.rb")
        evaluate_file("#{core_path}/string.rb")
        evaluate_file("#{core_path}/symbol.rb")
        evaluate_file("#{core_path}/array.rb")
        evaluate_file("#{core_path}/hash.rb")
        evaluate_file("#{core_path}/proc.rb")
        evaluate_file("#{core_path}/method.rb")
        evaluate_file("#{core_path}/unbound_method.rb")
        evaluate_file("#{core_path}/range.rb")
        evaluate_file("#{core_path}/enumerator.rb")
        evaluate_file("#{core_path}/signal.rb")
        evaluate_file("#{core_path}/exception.rb")
        evaluate_file("#{core_path}/errno.rb")
        evaluate_file("#{core_path}/math.rb")
        evaluate_file("#{core_path}/encoding.rb")
        evaluate_file("#{core_path}/match_data.rb")
        evaluate_file("#{core_path}/regexp.rb")
        evaluate_file("#{core_path}/rational.rb")
        evaluate_file("#{core_path}/complex.rb")
        evaluate_file("#{core_path}/io.rb")
        evaluate_file("#{core_path}/file.rb")
        evaluate_file("#{core_path}/file_test.rb")
        evaluate_file("#{core_path}/dir.rb")
        evaluate_file("#{core_path}/time.rb")
        evaluate_file("#{core_path}/mutex.rb")
        evaluate_file("#{core_path}/fiber.rb")
        evaluate_file("#{core_path}/thread.rb")
        evaluate_file("#{core_path}/process.rb")
        evaluate_file("#{core_path}/binding.rb")
        evaluate_file("#{core_path}/pp.rb")
        evaluate_file("#{core_path}/stringio.rb")
        evaluate_file("#{core_path}/struct.rb")
        evaluate_file("#{core_path}/data.rb")
        evaluate_file("#{core_path}/set.rb")
        evaluate_file("#{core_path}/random.rb")
        evaluate_file("#{core_path}/objectspace.rb")
        evaluate_file("#{core_path}/gc.rb")
        evaluate_file("#{core_path}/env.rb")
        evaluate_file("#{core_path}/rubygems.rb")
        evaluate_file("#{core_path}/marshal.rb")
        init_globals
      end

      # Attach 'main' proxy singleton methods for private/public/protected → Object
      def setup_main(main_obj)
        # Private proxy methods: private, public, protected, include, ruby2_keywords
        { private: :toplevel_private, public: :toplevel_public, protected: :toplevel_protected, include: :toplevel_include, ruby2_keywords: :toplevel_ruby2_keywords }.each do |name, intrinsic|
          body = Ast::IntrinsicCall.new(intrinsic, [Ast::SelfLiteral::SELF, Ast::LocalVariableRead.new(:names, 0)])
          m = Method.new([Core::OBJECT_CLASS], name, [], [], :names, [], [], [], nil, nil, [:names], body)
          m.visibility = :private
          main_obj.define_singleton_method(name, m)
        end
        # main.define_method(name, callable=nil, &block) — defines on Object as public (private access)
        define_method_body = Ast::IntrinsicCall.new(:toplevel_define_method, [Ast::SelfLiteral::SELF, Ast::LocalVariableRead.new(:args, 0), Ast::LocalVariableRead.new(:block, 0)])
        define_method_m = Method.new([Core::OBJECT_CLASS], :define_method, [], [], :args, [], [], [], nil, :block, %i[args block], define_method_body)
        define_method_m.visibility = :private
        main_obj.define_singleton_method(:define_method, define_method_m)
        # main.using(mod) — activates refinements in the current file scope (private)
        using_body = Ast::IntrinsicCall.new(:toplevel_using, [Ast::SelfLiteral::SELF, Ast::LocalVariableRead.new(:names, 0)])
        using_m = Method.new([Core::OBJECT_CLASS], :using, [], [], :names, [], [], [], nil, nil, [:names], using_body)
        using_m.visibility = :private
        main_obj.define_singleton_method(:using, using_m)
        # main.to_s / main.inspect return "main" (Ruby top-level object identity) — public
        main_str = Ast::StringLiteral.from("main")
        [:to_s, :inspect].each do |name|
          m = Method.new([Core::OBJECT_CLASS], name, [], [], nil, [], [], [], nil, nil, [], main_str)
          main_obj.define_singleton_method(name, m)
        end
      end

      def init_globals
        gem_paths = Gem::Specification.flat_map(&:full_require_paths).select { |p| File.directory?(p) }
        core_path = File.expand_path("../../core/#{FROZONE_CORE_VERSION}", __dir__)
        all_load_paths = ([core_path] + $LOAD_PATH + gem_paths).uniq.reject { |p| p == '.' || p == '' }
        sitelibdir = RbConfig::CONFIG['sitelibdir']
        site_idx = sitelibdir ? all_load_paths.index(sitelibdir) : nil
        load_path_objs = all_load_paths.each_with_index.map do |p, i|
          StringObject.new(p).tap { |s| s.set_ivar(:@gem_prelude_index, TrueObject::TRUE) if site_idx && i >= site_idx }
        end
        GLOBALS[:"$LOAD_PATH"] = ArrayObject.new(load_path_objs)
        # Pre-stub pp.rb: Frozone provides pretty_inspect/pp directly in core,
        # so pp.rb must not be loaded (it uses default-param tricks Frozone can't handle).
        pp_path = $LOAD_PATH.map { |d| File.join(d, 'pp.rb') }.find { |f| File.exist?(f) } || 'pp.rb'
        stringio_path = $LOAD_PATH.map { |d| File.join(d, 'stringio') }.find { |f| File.exist?("#{f}.so") || File.exist?("#{f}.rb") } || 'stringio'
        GLOBALS[:"$LOADED_FEATURES"] = ArrayObject.new([StringObject.new(pp_path), StringObject.new(stringio_path)])
        GLOBALS[:"$\""] = GLOBALS[:"$LOADED_FEATURES"]  # $" is alias for $LOADED_FEATURES
        GLOBALS[:"$/"] = StringObject.new("\n")
        GLOBALS[:"$\\"] = NilObject::NIL
        GLOBALS[:"$,"] = NilObject::NIL
        GLOBALS[:"$;"] = NilObject::NIL
        GLOBALS[:"$."] = IntegerObject.new(0)
        GLOBALS[:"$$"] = IntegerObject.new(Process.pid)
        GLOBALS[:"$VERBOSE"] = FalseObject::FALSE
        GLOBALS[:"$DEBUG"] = FalseObject::FALSE
        GLOBALS[:"$!"] = NilObject::NIL
        io_class = Core.io_class
        GLOBALS[:"$stdout"] = IOObject.new($stdout, io_class)
        GLOBALS[:"$stderr"] = IOObject.new($stderr, io_class)
        GLOBALS[:"$stdin"] = IOObject.new($stdin,  io_class)
        GLOBALS[:"$>"] = GLOBALS[:"$stdout"]
        GLOBALS[:"$<"] = GLOBALS[:"$stdin"]
        GLOBALS[:"$0"] = StringObject.new($PROGRAM_NAME.to_s)
        GLOBALS[:"$PROGRAM_NAME"] = GLOBALS[:"$0"]
        setup_frozone_land
      end

      # Set up the minimal Frozone-land infrastructure needed for self-hosting (Frozone²).
      #
      # 1. Pre-stubs all Frozone source files in Frozone-land $LOADED_FEATURES so that
      #    inner `require_relative 'lib/frozone/vm/vm'` etc. are no-ops.
      # 2. Creates a minimal Frozone-land Frozone::Vm::Vm class whose #run delegates
      #    to the outer Frozone's MRI evaluator via the kernel_run_vm intrinsic.
      def setup_frozone_land
        # Pre-stub Frozone source files so the inner Frozone's require calls skip them.
        frozone_src = File.expand_path('..', __dir__)       # lib/frozone/
        core_src = File.expand_path('../../core', __dir__) # lib/core/
        existing = GLOBALS[:"$LOADED_FEATURES"].raw.map(&:raw)
        $LOADED_FEATURES.each do |path|
          next unless (path.start_with?(frozone_src) || path.start_with?(core_src)) && path.end_with?('.rb')
          GLOBALS[:"$LOADED_FEATURES"].push(StringObject.new(path)) unless existing.include?(path)
        end

        # Only create the Frozone-land Frozone::Vm namespace once.
        return if Core::OBJECT_CLASS.get_constant(:Frozone)

        frozone_mod = ModuleObject.new(:Frozone, nil)
        vm_mod = ModuleObject.new(:Vm, frozone_mod)
        frozone_mod.set_constant(:Vm, vm_mod)
        Core::OBJECT_CLASS.set_constant(:Frozone, frozone_mod)

        vm_class = ClassObject.new(:Vm, vm_mod, Core::OBJECT_CLASS)
        vm_mod.set_constant(:Vm, vm_class)

        # Dummy Parser / WqParser constants so inner frozone.rb's
        #   Frozone::Vm.send(:remove_const, :Parser)
        #   Frozone::Vm::Parser = Frozone::Vm::WqParser
        # succeed without error (the classes themselves are never invoked).
        vm_mod.set_constant(:Parser,   ClassObject.new(:Parser,   vm_mod, Core::OBJECT_CLASS))
        vm_mod.set_constant(:WqParser, ClassObject.new(:WqParser, vm_mod, Core::OBJECT_CLASS))

        # Vm#initialize(options = {}) — stores Frozone-land options hash.
        init_body = Ast::IntrinsicCall.new(:kernel_vm_initialize,
                                             [Ast::SelfLiteral::SELF,
                                              Ast::LocalVariableRead.new(:options, 0)])
        init_method = Method.new([vm_class], :initialize,
                                 [], [[:options, Ast::HashLiteral.new([])]],
                                 nil, [],
                                 [], [],
                                 nil, nil,
                                 [:options],
                                 init_body)
        init_method.visibility = :private
        vm_class.set_method(:initialize, init_method)

        # Vm#run — delegates to outer Frozone's MRI evaluator.
        run_body = Ast::IntrinsicCall.new(:kernel_run_vm, [Ast::SelfLiteral::SELF])
        run_method = Method.new([vm_class], :run,
                                [], [],
                                nil, [],
                                [], [],
                                nil, nil,
                                [],
                                run_body)
        vm_class.set_method(:run, run_method)
      end

      private

      def parse(script, dump_ast = false, filepath: nil, raise_syntax_errors: false)
        parser = Parser.new(script, dump_ast, filepath: filepath)
        ast = parser.ast(raise_syntax_errors: raise_syntax_errors)
        ParseResult.new(
          ast,
          parser.top_level_locals,
          parser.prism_always_warnings,
          parser.prism_verbose_warnings,
        )
      end

      # Maps expanded file paths → their real (symlink-resolved) paths, populated at load time.
      # Used by Thread::Backtrace::Location#absolute_path to resolve symlinks correctly even
      # after the symlink is removed (matching MRI semantics: real path stored at load time).
      FILE_REALPATH_CACHE = {}

      # Set of canonical realpaths for every Ruby source file loaded
      # successfully during the run. For box-first AOT, this is the
      # closed-world's source-file universe — execute-phase requires
      # check candidate paths against this set. See
      # docs/box-first-load-execute-split.md for the design.
      # Populated alongside FILE_REALPATH_CACHE; snapshot
      # `build_files_at_load_phase_end` is captured by split_and_load
      # after the load AST evaluates, so that any subsequent loads
      # (e.g. lazy requires during execute) don't pollute the
      # closed-world set.
      BUILD_FILES = Set.new

      # Closed-world source-file universe captured at the load/execute
      # boundary in split_and_load. Returns nil before split_and_load
      # has run (e.g. straight `--flatten` without AOT split). Frozen.
      def self.build_files_at_load_phase_end
        @build_files_at_load_phase_end
      end

      # Split a Ruby file into load phase and execute phase, evaluate the
      # load phase, optionally flatten modules, then return the context
      # and execute nodes for the caller to handle.
      #
      # Used by both --aot (compile execute phase) and --flatten
      # (interpret execute phase with flattened class tables).
      def split_and_load(path, flatten: false)
        full_path = File.expand_path(path)
        source = File.read(full_path)
        parse_result = parse(source, false, filepath: full_path)
        ast = parse_result.ast

        load_nodes = []
        execute_nodes = []
        in_execute = false

        hoisted_class_constants = []
        hoist_consts = @options[:hoist_consts]
        Fiber[:aot_hoisted_consts] = hoist_consts ? hoisted_class_constants : nil
        nodes = ast.is_a?(Ast::Sequence) ? ast.nodes : [ast]
        nodes.each do |node|
          hoist_expensive_class_constants!(node, hoisted_class_constants) if hoist_consts
          if !in_execute && aot_load_phase_node?(node, hoist_consts: hoist_consts)
            load_nodes << node
          else
            in_execute = true
            execute_nodes << node
          end
        end

        $stderr.puts "frozone: #{load_nodes.size} load nodes, #{execute_nodes.size} execute nodes"

        (Fiber[:file_stack] ||= []) << full_path
        real_entry_path = begin; File.realpath(full_path); rescue; full_path; end
        FILE_REALPATH_CACHE[full_path] = real_entry_path
        BUILD_FILES << real_entry_path
        load_ast = Ast::Sequence.new(load_nodes)
        top_level_scope = Core::OBJECT_CLASS
        top_level_object = Fiber[:main_object] || ObjectObject.new(Core::OBJECT_CLASS)
        Fiber[:main_object] ||= top_level_object
        Core::OBJECT_CLASS.current_visibility = :private
        setup_main(top_level_object)

        context = Context.new
        Fiber[:context] = context
        Fiber[:vm_evaluate] = method(:evaluate_file)
        Fiber[:vm_eval]     = method(:evaluate)

        frame = Frame.new(top_level_object, parse_result.top_level_locals, [top_level_scope])
        frame.method_frame = frame
        context.push_frame(frame)
        context.push_scope(top_level_scope)

        load_ast.evaluate(context)

        # Snapshot the closed-world source-file universe at the
        # load/execute boundary. Anything subsequently loaded (e.g.
        # via runtime require during the interpreter execute path)
        # populates BUILD_FILES too but doesn't change this snapshot.
        # Box-first AOT execute-phase emission consults this set to
        # validate that runtime requires only target files in the
        # build. See docs/box-first-load-execute-split.md.
        Vm.instance_variable_set(:@build_files_at_load_phase_end, BUILD_FILES.dup.freeze)
        if ENV['FROZONE_AOT_DEBUG'] == '1'
          $stderr.puts "frozone: BUILD_FILES at load-phase-end: #{BUILD_FILES.size} files"
        end

        # Module erasure: flatten ancestor methods/constants into each
        # concrete class. For --aot this is before TI (codegen mode
        # renames prepend originals for Crystal super rewriting); for
        # --flatten this is before interpreting (no rename needed —
        # interpreter super uses live MRO).
        Frozone::Compiler::ModuleErasure.flatten!(top_level_scope, codegen: flatten == :codegen) if flatten

        execute_nodes = hoisted_class_constants + execute_nodes unless hoisted_class_constants.empty?
        Fiber[:aot_hoisted_consts] = nil

        [context, execute_nodes, full_path, load_nodes.size]
      end

      # --flatten mode: split, flatten modules, then INTERPRET the execute phase.
      # Same load/execute split as --aot but runs the execute phase under the
      # interpreter with flattened class tables. For A/B testing erasure.
      def flatten_and_run(path)
        context, execute_nodes, full_path, _ = split_and_load(path, flatten: :interpret)
        execute_ast = Ast::Sequence.new(execute_nodes)
        execute_ast.evaluate(context)
        Fiber[:file_stack]&.pop
      end

      # --aot mode: split, flatten modules, then compile the execute phase to Crystal.
      def aot_compile(path)
        context, execute_nodes, full_path, load_count = split_and_load(path, flatten: :codegen)

        # Closed-world enforcement (box-first AOT only): walk the
        # execute-phase AST and fail hard on violations — class /
        # module / method / const defs in execute phase, or requires
        # for files outside BUILD_FILES. See
        # docs/box-first-load-execute-split.md.
        if ENV['FROZONE_BOX_FIRST'] == '1'
          require_relative '../compiler/closed_world_validator'
          build_files = Vm.build_files_at_load_phase_end || Set.new
          Frozone::Compiler::ClosedWorldValidator.validate!(
            execute_nodes,
            build_files: build_files,
            file_stack: (Fiber[:file_stack] || []),
          )
        end

        # Compile execute phase: wrap in a Block and pass to FrozoneCompile.
        execute_ast = Ast::Sequence.new(execute_nodes)
        inner = execute_nodes.size == 1 && execute_nodes[0].is_a?(Ast::FrozoneCompile) ?
          execute_nodes[0].block_node.body : execute_ast
        block_node = Ast::Block.new(
          [], [], nil, [],   # required, optional, rest, post params
          [], [], nil, nil,  # kw params, block param
          false, [],         # auto_splat, locals
          inner,             # body
          source_location: [full_path, load_count + 1]
        )
        compile_node = Ast::FrozoneCompile.new(block_node, aot_mode: true)
        compile_node.evaluate(context)

        Fiber[:file_stack]&.pop
      end

      # Classify a top-level AST node as load phase (true) or execute phase (false).
      # Heuristic: a constant initializer is "cheap" iff its expression
      # tree contains no method calls that take a block. Block-bearing
      # calls (.map / .times / .each / etc.) are how big lookup tables
      # get built, and the interpreter is too slow for the inner loop.
      # Anything else — literals, arithmetic, string interpolation,
      # constant references, top-level method calls without blocks —
      # is fine to evaluate at load time.
      def cheap_constant_initializer?(node)
        return true if node.nil?
        return false if contains_block_call?(node)
        true
      end

      def contains_block_call?(node)
        return false unless node.is_a?(Ast::Node)
        return true if node.is_a?(Ast::MethodCall) && node.block_node
        return true if node.is_a?(Ast::Block)
        node.children.any? { |c| contains_block_call?(c) }
      end

      # Recursively walk a (possibly-nested) class/module body, find
      # ConstantWrite nodes whose RHS is expensive (block-bearing),
      # and hoist them as `Outer::Inner::CONST = expr` synthetic
      # `Ast::ConstantPathWrite` nodes appended to the `hoisted` list.
      # The original `Ast::ConstantWrite` is replaced in-place inside
      # the class body's Sequence with an `Ast::NilLiteral` placeholder
      # so the body still parses and executes cleanly.
      #
      # Only handles cases where the constant initialiser is
      # self-contained (doesn't reference siblings via bare name).
      # Conservative — bails out for nodes whose body shape isn't a
      # Sequence we can mutate.
      def hoist_expensive_class_constants!(node, hoisted, namespace_path = [])
        return unless node.is_a?(Ast::ClassDef) || node.is_a?(Ast::ModuleDef)
        path = namespace_path + [node.name]
        body = node.body
        return unless body.is_a?(Ast::Sequence)
        body.nodes.each_with_index do |child, idx|
          if child.is_a?(Ast::ConstantWrite) && !cheap_constant_initializer?(child.value_node)
            hoisted << build_path_write(path, child.name, child.value_node, child.source_location)
            body.nodes[idx] = Ast::NilLiteral::NIL
          else
            hoist_expensive_class_constants!(child, hoisted, path)
          end
        end
      end

      # Build a `Outer::Inner::CONST = value` AST: chain ConstantRead /
      # ConstantPath nodes for the namespace, then wrap in
      # ConstantPathWrite for the leaf assignment.
      def build_path_write(namespace_path, const_name, value_node, source_location)
        parent = Ast::ConstantRead.new(namespace_path.first)
        namespace_path[1..].each do |seg|
          parent = Ast::ConstantPath.new(parent, seg)
        end
        Ast::ConstantPathWrite.new(parent, const_name, value_node, source_location: source_location)
      end

      def aot_load_phase_node?(node, hoist_consts: false)
        case node
        when Ast::MethodCall
          # require, require_relative, and load are load-phase
          name = node.name
          return true if %i[require require_relative load].include?(name) && node.receiver_node.nil?
          # Top-level attribute methods (attr_reader, attr_writer, attr_accessor)
          return true if %i[attr_reader attr_writer attr_accessor].include?(name) && node.receiver_node.nil?
          # Method calls on global variables ($LOADED_FEATURES << x, etc.)
          return true if node.receiver_node.is_a?(Ast::GlobalVariableRead)
          false
        when Ast::AttributeWrite
          # ENV[k] = v is conventionally load-phase configuration; otherwise
          # the splitter would flip into execute mode and any subsequent
          # require_relative would be deferred to runtime, breaking AOT.
          return true if node.name == :[]= && node.receiver_node.is_a?(Ast::ConstantRead) && node.receiver_node.name == :ENV
          false
        when Ast::MethodDef, Ast::ClassDef, Ast::ModuleDef, Ast::SingletonClassDef
          true
        when Ast::ConstantWrite
          # When --hoist-class-consts is on, constants with cheap RHS
          # (literals, arithmetic, nested literal collections) stay in
          # the load phase, while expensive iteration-based initialisers
          # (like optcarrot's `TILE_LUT = (0...0x10000).map { ... }`)
          # get pushed into the execute phase so they're built by
          # compiled Crystal at binary startup, not interpreted at AOT
          # load time. Without the flag, all ConstantWrites are load
          # (the original Frozone behaviour).
          hoist_consts ? cheap_constant_initializer?(node.value_node) : true
        when Ast::ConstantPath
          true
        when Ast::GlobalVariableWrite
          true
        when Ast::Sequence
          # A sequence where ALL children are load-phase is load-phase
          node.nodes.all? { |n| aot_load_phase_node?(n, hoist_consts: hoist_consts) }
        else
          false
        end
      end

      def evaluate_file(path, raise_syntax_errors: false)
        full_path = File.expand_path(path)
        real_path = begin
          File.realpath(full_path)
        rescue Errno::ENOENT, Errno::EACCES
          full_path
        end
        FILE_REALPATH_CACHE[full_path] = real_path
        BUILD_FILES << real_path
        (Fiber[:file_stack] ||= []) << full_path
        begin
          evaluate(File.read(full_path), false, filepath: full_path, raise_syntax_errors: raise_syntax_errors)
        rescue FrozoneException => e
          # Set @path on SyntaxError when loading/requiring a file
          vo = e.vm_object
          if vo.is_a?(ObjectObject) && vo.class_object&.name == :SyntaxError
            vo.set_ivar(:@path, StringObject.new(full_path))
          end
          raise
        ensure
          Fiber[:file_stack].pop
        end
      end

      def evaluate(script, dump_ast = false, filepath: nil, raise_syntax_errors: false)
        parse_result = parse(script, dump_ast, filepath: filepath, raise_syntax_errors: raise_syntax_errors)
        ast = parse_result.ast

        # When AOT compiling with --hoist-class-consts, walk every
        # parsed file (not just the top-level entry) for expensive
        # class-body constant initialisers. The mutation is in-place
        # — the original ConstantWrite becomes a nil placeholder so
        # the load-phase interpreter skips the heavy work — and the
        # hoisted assignments are stashed in Fiber[:aot_hoisted_consts]
        # for aot_compile to splice into the execute phase later.
        hoist_list = Fiber[:aot_hoisted_consts]
        if hoist_list && ast
          (ast.is_a?(Ast::Sequence) ? ast.nodes : [ast]).each do |n|
            hoist_expensive_class_constants!(n, hoist_list)
          end
        end

        if dump_ast
          puts
          puts ast
        end

        top_level_scope = Core::OBJECT_CLASS
        wrap_mod = Fiber[:load_wrap_module]
        # Reuse the shared main object across require/load so that `def self.foo` in a
        # required file adds to the shared main's singleton class (matching MRI semantics).
        # When load(path, true/mod) is used, a fresh object is used with wrap_mod attached.
        main_obj = Fiber[:main_object]
        top_level_object = (main_obj && !wrap_mod) ? main_obj : ObjectObject.new(Core::OBJECT_CLASS)
        # Track the primary (first) top-level main object for load(path,true) module inheritance.
        Fiber[:main_object] ||= top_level_object if @in_main_eval && !wrap_mod
        Core::OBJECT_CLASS.current_visibility = :private
        setup_main(top_level_object)
        if wrap_mod
          wrap_mod.current_visibility = :private  # top-level defs in wrapped files are private
          # Copy caller's singleton class modules so they appear in the wrapped self's ancestor chain:
          # [singleton_class, wrap_mod, *caller_sc_modules, Object, Kernel, BasicObject]
          receiver_sc_mods = Fiber[:load_wrap_receiver_sc_mods] || []
          # add_module uses unshift; add oldest-first so newest ends up first (after wrap_mod)
          receiver_sc_mods.reverse_each { |m| top_level_object.singleton_class.add_module(m) }
          top_level_object.singleton_class.add_module(wrap_mod)  # prepended last → first in chain
        end

        context = Context.new
        Fiber[:context] = context
        Fiber[:vm_evaluate] = method(:evaluate_file)
        Fiber[:vm_eval]     = method(:evaluate)

        frame = Frame.new(top_level_object, parse_result.top_level_locals, wrap_mod ? [Core::OBJECT_CLASS, wrap_mod] : [top_level_scope])
        # top-level frame acts as a method frame: procs defined here can `return`
        # from this scope (e.g. `proc { return }.call` in a loaded file exits the load).
        frame.method_frame = frame
        context.push_frame(frame)
        context.push_scope(top_level_scope)
        context.push_scope(wrap_mod) if wrap_mod
        # Set TOPLEVEL_BINDING to the top-level frame binding (only for the first/real main evaluation,
        # not during core-library loading or subsequent require/load calls).
        if @in_main_eval && !wrap_mod && !Core::OBJECT_CLASS.lookup_constant(:TOPLEVEL_BINDING).is_a?(BindingObject)
          Core::OBJECT_CLASS.set_constant(:TOPLEVEL_BINDING, BindingObject.new(frame))
        end

        begin
          ast.evaluate(context)
        rescue Ast::ReturnException
          # `return` at the top level of the main script (or a loaded file) exits gracefully.
          # For loaded files kernel_load/kernel_require catch this; for the main script we absorb here.
          NilObject::NIL
        ensure
          frame.kill!
        end
      end
    end
  end
end
