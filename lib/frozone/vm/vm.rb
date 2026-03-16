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
        ruby_engine      = StringObject.new('frozone')
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

        env_hash = HashObject.new(ENV.to_h { |k, v| [StringObject.new(k), StringObject.new(v)] })
        Core::OBJECT_CLASS.set_constant(:ENV, env_hash)

        Core::OBJECT_CLASS.set_constant(:STDOUT, GLOBALS[:"$stdout"])
        Core::OBJECT_CLASS.set_constant(:STDERR, GLOBALS[:"$stderr"])
        Core::OBJECT_CLASS.set_constant(:STDIN,  GLOBALS[:"$stdin"])

        Core::OBJECT_CLASS.set_constant(:TOPLEVEL_BINDING, NilObject::NIL)
        Core::OBJECT_CLASS.set_constant(:ARGF, GLOBALS[:"$<"] || NilObject::NIL)

        script_argv = @options[:argv][1..] || []
        Core::OBJECT_CLASS.set_constant(:ARGV, ArrayObject.new(script_argv.map { |a| StringObject.new(a) }))

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
              break if cls.name == :SystemExit
              cls = cls.superclass
            end
            if cls
              status_obj = vm_obj.get_ivar(:@status)
              exit(status_obj.is_a?(IntegerObject) ? status_obj.raw : 0)
            end
          end
          raise
        end
      end

      # Load the standard library into the shared class hierarchy.
      # Idempotent: safe to call multiple times (methods are simply redefined).
      def load_core
        core_path = File.expand_path("../../core/#{FROZONE_CORE_VERSION}", __dir__)
        evaluate_file("#{core_path}/module.rb")
        evaluate_file(File.expand_path("hierarchy.rb", __dir__))
        ObjectObject.end_bootstrap!
        evaluate_file("#{core_path}/class.rb")
        evaluate_file("#{core_path}/basic_object.rb")
        evaluate_file("#{core_path}/kernel.rb")
        evaluate_file("#{core_path}/object.rb")
        evaluate_file("#{core_path}/comparable.rb")
        evaluate_file("#{core_path}/enumerable.rb")
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
        evaluate_file("#{core_path}/binding.rb")
        evaluate_file("#{core_path}/pp.rb")
        evaluate_file("#{core_path}/stringio.rb")
        evaluate_file("#{core_path}/set.rb")
        evaluate_file("#{core_path}/random.rb")
        init_globals
      end

      # Attach 'main' proxy singleton methods for private/public/protected → Object
      def setup_main(main_obj)
        { private: :toplevel_private, public: :toplevel_public, protected: :toplevel_protected, include: :toplevel_include }.each do |name, intrinsic|
          body = Ast::IntrinsicCall.new(intrinsic, [Ast::SelfLiteral::SELF, Ast::LocalVariableRead.new(:names, 0)])
          m = Method.new([Core::OBJECT_CLASS], name, [], [], :names, [], [], [], nil, nil, [:names], body)
          main_obj.define_singleton_method(name, m)
        end
        # main.to_s / main.inspect return "main" (Ruby top-level object identity)
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
        sitelibdir = RbConfig::CONFIG['sitelibdir'] rescue nil
        site_idx = sitelibdir ? all_load_paths.index(sitelibdir) : nil
        load_path_objs = all_load_paths.each_with_index.map do |p, i|
          s = StringObject.new(p)
          s.set_ivar(:@gem_prelude_index, TrueObject::TRUE) if site_idx && i >= site_idx
          s
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
        GLOBALS[:"$0"]               = StringObject.new($0.to_s)
        GLOBALS[:"$PROGRAM_NAME"]    = GLOBALS[:"$0"]
      end

      # Evaluate a Ruby snippet and return the resulting VM object.
      def eval_snippet(code, dump_ast = false)
        evaluate(code, dump_ast)
      end

      private

      def evaluate_file(path, raise_syntax_errors: false)
        full_path = File.expand_path(path)
        (Fiber[:file_stack] ||= []) << full_path
        begin
          evaluate(File.read(full_path), false, filepath: full_path, raise_syntax_errors: raise_syntax_errors)
        rescue FrozoneException => e
          # Set @path on SyntaxError when loading/requiring a file
          vo = e.vm_object
          if vo.respond_to?(:class_object) && vo.class_object&.name == :SyntaxError
            vo.set_ivar(:@path, StringObject.new(full_path))
          end
          raise
        ensure
          Fiber[:file_stack].pop
        end
      end

      def evaluate(script, dump_ast = false, filepath: nil, raise_syntax_errors: false)
        parser = Parser.new(script, dump_ast, filepath: filepath)
        ast = parser.ast(raise_syntax_errors: raise_syntax_errors)

        if dump_ast
          puts
          puts ast
        end

        top_level_scope = Core::OBJECT_CLASS
        top_level_object = ObjectObject.new(Core::OBJECT_CLASS)
        Core::OBJECT_CLASS.current_visibility = :private
        setup_main(top_level_object)

        context = Context.new
        Fiber[:context] = context
        Fiber[:vm_evaluate] = method(:evaluate_file)

        frame = Frame.new(top_level_object, parser.top_level_locals, [top_level_scope])
        # top-level frame acts as a method frame: procs defined here can `return`
        # from this scope (e.g. `proc { return }.call` in a loaded file exits the load).
        frame.method_frame = frame
        context.push_frame(frame)
        context.push_scope(top_level_scope)
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
