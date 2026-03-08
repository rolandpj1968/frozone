require_relative 'core'

require_relative 'parser'

require_relative 'context'
require_relative 'frame'
require_relative 'method'

require_relative 'nil_object'

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
        evaluate_file("#{core_path}/class.rb")
        evaluate_file("#{core_path}/basic_object.rb")
        evaluate_file("#{core_path}/object.rb")
        evaluate_file("#{core_path}/integer.rb")
      end

      # Evaluate a Ruby snippet and return the resulting VM object.
      def eval_snippet(code, dump_ast = false)
        evaluate(code, dump_ast)
      end

      private

      def evaluate_file(path) = evaluate(File.read(path))

      def evaluate(script, dump_ast = false)
        ast = Parser.new(script, dump_ast).ast

        if dump_ast
          puts
          puts ast
        end

        top_level_scope = Core::OBJECT_CLASS
        top_level_object = ObjectObject.new(Core::OBJECT_CLASS)

        context = Context.new

        frame = Frame.new(top_level_object, [], [top_level_scope])
        context.push_frame(frame)
        context.push_scope(top_level_scope)

        ast.evaluate(context)
      end
    end
  end
end
