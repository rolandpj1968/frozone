require 'prism'
require 'prism/translation/parser'
require 'parser/ruby34'

module Frozone
  module Vm
    # DualParser runs the same source through two independent parsers and compares
    # their s-expression outputs:
    #
    #   Parser A: whitequark `parser` gem (Parser::Ruby34) — pure Ruby, self-hostable
    #   Parser B: Prism::Translation::Parser40 — stdlib Prism translated to same format
    #
    # Both produce identical Parser::AST::Node s-expressions, so mismatches reveal
    # bugs in either parser.  The primary motivation is to validate Parser::Ruby34
    # as a future self-hostable replacement for the Prism C-extension dependency.
    #
    # Usage:
    #   result = DualParser.parse(source)
    #   result.ast         # => Parser::AST::Node (from primary parser)
    #   result.agree?      # => true if both parsers produced the same AST
    #   result.diff        # => nil or a human-readable mismatch description
    #
    # To enable agreement checking across the whole VM, set the env var:
    #   FROZONE_DUAL_PARSER=1
    module DualParser
      Result = Struct.new(:ast, :ast_prism, :errors_primary, :errors_prism, keyword_init: true) do
        def agree?
          ast.inspect == ast_prism.inspect
        end

        def diff
          return nil if agree?

          a = ast.inspect
          b = ast_prism.inspect
          "parser/ruby34 vs prism/translation differ:\n  A: #{a[0, 200]}\n  B: #{b[0, 200]}"
        end
      end

      def self.parse(source, filename: '(string)')
        buf = ::Parser::Source::Buffer.new(filename, source: source)

        ast_primary = nil
        errors_primary = []
        begin
          parser_a = ::Parser::Ruby34.new
          parser_a.diagnostics.all_errors_are_fatal = false
          parser_a.diagnostics.ignore_warnings      = true
          ast_primary = parser_a.parse(buf)
        rescue => e
          errors_primary = [e.message]
        end

        ast_prism = nil
        errors_prism = []
        begin
          # Prism::Translation::Parser40 uses the same Builder protocol
          parser_b = Prism::Translation::Parser40.new
          parser_b.diagnostics.all_errors_are_fatal = false
          parser_b.diagnostics.ignore_warnings      = true
          ast_prism = parser_b.parse(buf)
        rescue => e
          errors_prism = [e.message]
        end

        Result.new(ast: ast_primary, ast_prism: ast_prism,
                   errors_primary: errors_primary, errors_prism: errors_prism)
      end

      # Convenience: raise if the two parsers disagree.
      def self.parse!(source, filename: '(string)')
        result = parse(source, filename: filename)
        raise "DualParser mismatch for #{filename}: #{result.diff}" unless result.agree?

        result
      end
    end
  end
end
