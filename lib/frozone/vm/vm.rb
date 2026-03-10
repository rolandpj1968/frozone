require_relative 'core'
require_relative 'globals'
require_relative 'proc_object'

require_relative 'parser'

require_relative 'context'
require_relative 'frame'
require_relative 'method'

require_relative 'nil_object'
require_relative 'range_object'
require_relative 'float_object'
require_relative 'time_object'
require_relative 'regexp_object'

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

        Core::OBJECT_CLASS.set_constant(:RUBY_VERSION, StringObject.new('4.0.1'))
        Core::OBJECT_CLASS.set_constant(:RUBY_PLATFORM, StringObject.new(RUBY_PLATFORM))
        Core::OBJECT_CLASS.set_constant(:RUBY_ENGINE, StringObject.new('frozone'))
        Core::OBJECT_CLASS.set_constant(:RUBY_ENGINE_VERSION, StringObject.new('4.0.1'))
        Core::OBJECT_CLASS.set_constant(:RUBY_PATCHLEVEL, IntegerObject.new(-1))
        Core::OBJECT_CLASS.set_constant(:RUBY_REVISION, StringObject.new('0'))
        Core::OBJECT_CLASS.set_constant(:RUBY_RELEASE_DATE, StringObject.new('2025-01-01'))
        Core::OBJECT_CLASS.set_constant(:RUBY_DESCRIPTION, StringObject.new("frozone 4.0.1 (#{RUBY_PLATFORM})"))
        Core::OBJECT_CLASS.set_constant(:RUBY_COPYRIGHT, StringObject.new('frozone - Copyright (C) 2024 frozone'))

        env_hash = HashObject.new(ENV.to_h { |k, v| [StringObject.new(k), StringObject.new(v)] })
        Core::OBJECT_CLASS.set_constant(:ENV, env_hash)

        script_argv = @options[:argv][1..] || []
        Core::OBJECT_CLASS.set_constant(:ARGV, ArrayObject.new(script_argv.map { |a| StringObject.new(a) }))

        scripts = @options[:scripts]

        # if -e is present then ruby DOES NOT evaluate an ARGV file
        # Note: ruby -e 'ARGV.each {|f| load f}' file1.rb file2.rb file3.rb
        result =
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

        # puts "result: #{result}"  # debug
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
        evaluate_file("#{core_path}/object.rb")
        evaluate_file("#{core_path}/comparable.rb")
        evaluate_file("#{core_path}/nil_class.rb")
        evaluate_file("#{core_path}/true_class.rb")
        evaluate_file("#{core_path}/false_class.rb")
        evaluate_file("#{core_path}/integer.rb")
        evaluate_file("#{core_path}/string.rb")
        evaluate_file("#{core_path}/symbol.rb")
        evaluate_file("#{core_path}/array.rb")
        evaluate_file("#{core_path}/hash.rb")
        evaluate_file("#{core_path}/proc.rb")
        evaluate_file("#{core_path}/range.rb")
        evaluate_file("#{core_path}/exception.rb")
        evaluate_file("#{core_path}/pp.rb")
        init_globals
      end

      # Attach 'main' proxy singleton methods for private/public/protected → Object
      def setup_main(main_obj)
        { private: :toplevel_private, public: :toplevel_public, protected: :toplevel_protected }.each do |name, intrinsic|
          body = Ast::IntrinsicCall.new(intrinsic, [Ast::SelfLiteral::SELF, Ast::LocalVariableRead.new(:names, 0)])
          m = Method.new([Core::OBJECT_CLASS], name, [], [], :names, [], [], [], nil, nil, [:names], body)
          main_obj.define_singleton_method(name, m)
        end
      end

      def init_globals
        gem_paths = Gem::Specification.flat_map(&:full_require_paths).select { |p| File.directory?(p) }
        all_load_paths = ($LOAD_PATH + gem_paths).uniq
        GLOBALS[:"$LOAD_PATH"]       = ArrayObject.new(all_load_paths.map { |p| StringObject.new(p) })
        # Pre-stub pp.rb: Frozone provides pretty_inspect/pp directly in core,
        # so pp.rb must not be loaded (it uses default-param tricks Frozone can't handle).
        pp_path = $LOAD_PATH.map { |d| File.join(d, 'pp.rb') }.find { |f| File.exist?(f) } || 'pp.rb'
        GLOBALS[:"$LOADED_FEATURES"] = ArrayObject.new([StringObject.new(pp_path)])
        GLOBALS[:"$stdout"]          = ObjectObject.new(Core::OBJECT_CLASS) # placeholder
        GLOBALS[:"$0"]               = StringObject.new($0.to_s)
        GLOBALS[:"$PROGRAM_NAME"]    = GLOBALS[:"$0"]
      end

      # Evaluate a Ruby snippet and return the resulting VM object.
      def eval_snippet(code, dump_ast = false)
        evaluate(code, dump_ast)
      end

      private

      def evaluate_file(path)
        full_path = File.expand_path(path)
        (Fiber[:file_stack] ||= []) << full_path
        begin
          evaluate(File.read(full_path), false, filepath: full_path)
        ensure
          Fiber[:file_stack].pop
        end
      end

      def evaluate(script, dump_ast = false, filepath: nil)
        parser = Parser.new(script, dump_ast, filepath: filepath)
        ast = parser.ast

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
        context.push_frame(frame)
        context.push_scope(top_level_scope)

        ast.evaluate(context)
      end
    end
  end
end
