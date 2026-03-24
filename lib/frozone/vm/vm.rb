require_relative 'core'
require_relative 'globals'
require_relative 'proc_object'

require_relative 'parser'
require_relative 'ast_cache'

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

module Frozone
  module Vm
    class Vm
      # TODO - the most recent docs as of time of writing
      #   https://docs.ruby-lang.org/en/4.0/
      FROZONE_CORE_VERSION = "4.0"

      def initialize(options = {})
        @options = options
      end

      def run
        load_core

        ruby_version     = StringObject.new('4.0.1')
        ruby_platform    = StringObject.new(RUBY_PLATFORM)
        ruby_engine      = StringObject.new('ruby')
        ruby_eng_version = StringObject.new('4.0.1')
        ruby_patchlevel  = IntegerObject.new(-1)
        ruby_revision    = StringObject.new('0')
        ruby_release     = StringObject.new('2025-01-01')
        ruby_description = StringObject.new("frozone 4.0.1 (#{RUBY_PLATFORM})")
        ruby_copyright   = StringObject.new('frozone - Copyright (C) 2024 frozone')
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

        # if -e is present then ruby DOES NOT evaluate an ARGV file
        # Note: ruby -e 'ARGV.each {|f| load f}' file1.rb file2.rb file3.rb
        begin
          if scripts.empty?
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
        evaluate_file("#{core_path}/range.rb")
        evaluate_file("#{core_path}/enumerator.rb")
        evaluate_file("#{core_path}/exception.rb")
        evaluate_file("#{core_path}/encoding.rb")
        evaluate_file("#{core_path}/match_data.rb")
        evaluate_file("#{core_path}/regexp.rb")
        evaluate_file("#{core_path}/rational.rb")
        evaluate_file("#{core_path}/io.rb")
        evaluate_file("#{core_path}/file.rb")
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
        GLOBALS[:"$/"]               = StringObject.new("\n")
        GLOBALS[:"$\\"]              = NilObject::NIL
        GLOBALS[:"$,"]               = NilObject::NIL
        GLOBALS[:"$;"]               = NilObject::NIL
        GLOBALS[:"$."]               = IntegerObject.new(0)
        GLOBALS[:"$$"]               = IntegerObject.new(Process.pid)
        GLOBALS[:"$VERBOSE"]         = FalseObject::FALSE
        GLOBALS[:"$DEBUG"]           = FalseObject::FALSE
        GLOBALS[:"$!"]               = NilObject::NIL
        io_class = Core.io_class
        GLOBALS[:"$stdout"]          = IOObject.new($stdout, io_class)
        GLOBALS[:"$stderr"]          = IOObject.new($stderr, io_class)
        GLOBALS[:"$stdin"]           = IOObject.new($stdin,  io_class)
        GLOBALS[:"$>"]               = GLOBALS[:"$stdout"]
        GLOBALS[:"$<"]               = GLOBALS[:"$stdin"]
        GLOBALS[:"$0"]               = StringObject.new($PROGRAM_NAME.to_s)
        GLOBALS[:"$PROGRAM_NAME"]    = GLOBALS[:"$0"]
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
        core_src    = File.expand_path('../../core', __dir__) # lib/core/
        existing    = GLOBALS[:"$LOADED_FEATURES"].raw.map(&:raw)
        $LOADED_FEATURES.each do |path|
          next unless (path.start_with?(frozone_src) || path.start_with?(core_src)) && path.end_with?('.rb')
          GLOBALS[:"$LOADED_FEATURES"].push(StringObject.new(path)) unless existing.include?(path)
        end

        # Only create the Frozone-land Frozone::Vm namespace once.
        return if Core::OBJECT_CLASS.get_constant(:Frozone)

        frozone_mod = ModuleObject.new(:Frozone, nil)
        vm_mod      = ModuleObject.new(:Vm, frozone_mod)
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
        init_body   = Ast::IntrinsicCall.new(:kernel_vm_initialize,
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
        run_body   = Ast::IntrinsicCall.new(:kernel_run_vm, [Ast::SelfLiteral::SELF])
        run_method = Method.new([vm_class], :run,
                                [], [],
                                nil, [],
                                [], [],
                                nil, nil,
                                [],
                                run_body)
        vm_class.set_method(:run, run_method)
      end

      # Evaluate a Ruby snippet and return the resulting VM object.
      def eval_snippet(code, dump_ast = false)
        evaluate(code, dump_ast, filepath: "-e")
      end

      private

      def parser_name
        @parser_name ||= begin
          defined?(WqParser) && Parser == WqParser ? "wq" : "prism"
        end
      end

      def cached_parse(script, dump_ast = false, filepath: nil, raise_syntax_errors: false)
        # Only cache when not dumping AST and caching is not disabled.
        # eval() calls (with outer_locals) go through Parser directly, not here.
        if !dump_ast && AstCache.enabled?
          # L1: in-memory cache by [filepath, mtime] — no SHA256 needed, no disk I/O.
          if filepath && (cached = AstCache.fetch_file(filepath, parser_name))
            return cached
          end
          # L2: on-disk content-addressed cache by SHA256(source).
          cached = AstCache.fetch(script, parser_name)
          return cached if cached
        end

        parser = Parser.new(script, dump_ast, filepath: filepath)
        ast = parser.ast(raise_syntax_errors: raise_syntax_errors)
        result = AstCache::ParseResult.new(
          ast,
          parser.top_level_locals,
          parser.prism_always_warnings,
          parser.prism_verbose_warnings,
        )

        if !dump_ast && AstCache.enabled?
          AstCache.store(script, parser_name, result)
          AstCache.store_file(filepath, parser_name, result) if filepath
        end

        result
      end

      def evaluate_file(path, raise_syntax_errors: false)
        full_path = File.expand_path(path)
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
        parse_result = cached_parse(script, dump_ast, filepath: filepath, raise_syntax_errors: raise_syntax_errors)
        ast = parse_result.ast

        if dump_ast
          puts
          puts ast
        end

        top_level_scope = Core::OBJECT_CLASS
        top_level_object = ObjectObject.new(Core::OBJECT_CLASS)
        # When load(path, true/mod) is used, wrap the loaded file in an anonymous module.
        # Constants and method definitions go into wrap_mod (innermost scope).
        # The wrap_mod is extended into top_level_object's singleton class so that
        # methods defined in the file are callable without explicit receiver during load,
        # but are NOT accessible on the caller's main object afterward.
        wrap_mod = Fiber[:load_wrap_module]
        # Track the primary (first) top-level main object for load(path,true) module inheritance.
        Fiber[:main_object] ||= top_level_object unless wrap_mod
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
        # Set TOPLEVEL_BINDING to the top-level frame binding
        Core::OBJECT_CLASS.set_constant(:TOPLEVEL_BINDING, BindingObject.new(frame))

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
