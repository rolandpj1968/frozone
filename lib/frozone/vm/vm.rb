require_relative 'core'
require_relative 'globals'
require_relative 'proc_object'

require_relative 'parser'

require_relative 'context'
require_relative 'frame'
require_relative 'method'

require_relative 'nil_object'
require_relative 'range_object'

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

        Core::OBJECT_CLASS.set_constant(:RUBY_VERSION, Ast::StringLiteral.from('4.0.1'))

        scripts = @options[:scripts]

        # if -e is present then ruby DOES NOT evaluate an ARGV file
        # Note: ruby -e 'ARGV.each {|f| load f}' file1.rb file2.rb file3.rb
        program =
          if scripts.empty?
            # if -e is absent then ruby evaluates the FIRST file only
            file = @options[:argv][0]
            file.nil? ? "" : File.read(file)
          else
            # if multiple -e scripts are present, ruby simply joins them with \n, and parses together
            #   ruby -e 'puts 3; class A' -e 'end; puts 4'
            #   ruby -e 'puts "ha' -e 'llo"'
            #   ruby -e 'puts 3' -e '@%@#$%@'
            scripts.join("\n")
          end

        result = eval_snippet(program, dump_ast = false) # TODO use cmd-line debug flag to dump AST

        puts "result: #{result}"
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
        GLOBALS[:"$LOAD_PATH"]       = ArrayObject.new([])
        GLOBALS[:"$LOADED_FEATURES"] = ArrayObject.new([])
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
        (Fiber[:file_stack] ||= []) << File.expand_path(path)
        begin
          evaluate(File.read(path))
        ensure
          Fiber[:file_stack].pop
        end
      end

      def evaluate(script, dump_ast = false)
        ast = Parser.new(script, dump_ast).ast

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

        frame = Frame.new(top_level_object, [], [top_level_scope])
        context.push_frame(frame)
        context.push_scope(top_level_scope)

        ast.evaluate(context)
      end
    end
  end
end
