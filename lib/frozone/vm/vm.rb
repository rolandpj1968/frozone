require_relative 'core'

require_relative 'parser'

require_relative 'context'
require_relative 'frame'
require_relative 'method'

require_relative 'nil_object'

module Frozone
  module Vm
    class Vm
      def initialize(options)
        @options = options
      end

      def run
        load_core

        Core::OBJECT_CLASS.set_constant(:RUBY_VERSION, Ast::StringLiteral.from('4.0.1'))

        # Core::INTEGER_CLASS.set_method(
        #   :+,
        #   Method.new(
        #     [Core::INTEGER_CLASS], # scopes
        #     :+,
        #     [:v],
        #     [:v],
        #     Ast::IntrinsicCall.new(
        #       '::Frozone::Vm::IntegerObject',
        #       :add,
        #       [
        #         Ast::SelfLiteral::SELF,
        #         Ast::LocalVariableRead.new(:v, 3)
        #       ]
        #     )
        #   )
        # )

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

        result = evaluate(program, dump_ast = true)

        puts
        puts "result: #{result}"

        puts
        puts "Strings: #{Ast::StringLiteral::StringLiterals.transform_values(&:to_s)}"
        puts
        puts "Symbols: #{Ast::SymbolLiteral::SymbolLiterals.transform_values(&:to_s)}"
        puts
        puts "Integers: #{Ast::IntegerLiteral::IntegerLiterals.transform_values(&:to_s)}"
        puts
        puts "Intrinsics: #{Ast::IntrinsicCall::Methods.transform_values(&:to_s)}"
      end

      private

      def evaluate_file(path) = evaluate(File.read(path))

      # TODO - the most recent docs as of time of writing
      #   https://docs.ruby-lang.org/en/4.0/
      FROZONE_CORE_VERSION = "4.0"
      def load_core
        version = FROZONE_CORE_VERSION
        puts Dir.pwd
        core_path = "./lib/core/#{version}" # TODO - work out frozone dir

        # TODO - read list from manifest somewhere...
        evaluate_file("#{core_path}/basic_object.rb")
        evaluate_file("#{core_path}/integer.rb")
      end

      def evaluate(script, dump_ast = false)
        #puts "Executing: '#{script}'"

        ast = Parser.new(script, dump_ast).ast

        if dump_ast
          puts
          puts ast
        end

        # puts
        # puts "AST root isa #{ast.class}"
        # puts
        # puts "AST: #{ast}"

        # TODO - top-level object, locals, etc.
        # Note: top-level object and state are shared for all scripts
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
