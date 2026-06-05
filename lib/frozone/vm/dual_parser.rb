require 'prism'
require 'prism/translation/parser'
require 'parser/ruby40'

module Frozone
  module Vm
    # DualParser runs the same source through two independent parsers and compares
    # their s-expression outputs:
    #
    #   Parser A: whitequark `parser` gem (Parser::Ruby40) — pure Ruby, self-hostable
    #   Parser B: Prism::Translation::Parser40 — stdlib Prism translated to same format
    #
    # Both produce identical Parser::AST::Node s-expressions, so mismatches reveal
    # bugs in either parser.  The primary motivation is to validate Parser::Ruby40
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
        def agree? = DualParser.normalise(ast).inspect == DualParser.normalise(ast_prism).inspect

        def diff
          return nil if agree?

          a = DualParser.normalise(ast).inspect
          b = DualParser.normalise(ast_prism).inspect
          "parser/ruby40 vs prism/translation differ:\n  A: #{a[0, 200]}\n  B: #{b[0, 200]}"
        end
      end

      # Bridge known asymmetries between Parser::Ruby40 (under modernize)
      # and Prism::Translation::Parser40. Translation gaps in Prism's side
      # — not Frozone bugs.
      def self.normalise(node)
        return node unless node.is_a?(::Parser::AST::Node)

        children = node.children.map { |c| normalise(c) }
        # `->` lambda: Ruby40 modernize → s(:lambda); Prism → s(:send, nil, :lambda)
        return ::Parser::AST::Node.new(:lambda, []) if node.type == :send && children == [nil, :lambda]
        # procarg0 wrapper: Ruby40 wraps single-block-arg in s(:procarg0, s(:arg, :x))
        # or s(:procarg0, :x) depending on flag; Prism never emits procarg0 — just s(:arg, :x).
        # Collapse both forms to s(:arg, :x).
        if node.type == :procarg0 && children.length == 1
          child = children.first
          return ::Parser::AST::Node.new(:arg, [child]) if child.is_a?(Symbol)
          return child if child.is_a?(::Parser::AST::Node) && child.type == :arg
        end
        # `recv[*args]` and `recv[*args] = v`: Ruby40 modernize emits
        # s(:index, …) for reads and s(:indexasgn, …) for writes (incl.
        # or_asgn LHS); Prism stays with s(:send, recv, :[], …) / s(:send,
        # recv, :[]=, …) for both — AND uses s(:index, …) for or_asgn
        # LHS. Canonicalise all four forms to s(:index, recv, *args).
        if node.type == :send && children.length >= 2 && (children[1] == :[] || children[1] == :[]=)
          return ::Parser::AST::Node.new(:index, [children[0], *children[2..]])
        end
        if node.type == :indexasgn
          return ::Parser::AST::Node.new(:index, children)
        end
        # Trailing keyword args: Ruby40 modernize wraps in s(:kwargs, …);
        # Prism keeps them as s(:hash, …).
        if node.type == :kwargs
          return ::Parser::AST::Node.new(:hash, children)
        end
        # `def foo(...)` argument forwarding: Ruby40 modernize emits
        # s(:args, s(:forward_arg)); Prism emits a flat s(:forward_args).
        # Canonicalise both to s(:forward_args).
        if node.type == :args && children.length == 1 &&
           children.first.is_a?(::Parser::AST::Node) && children.first.type == :forward_arg
          return ::Parser::AST::Node.new(:forward_args, [])
        end
        node.updated(nil, children)
      end

      def self.parse(source, filename: '(string)')
        buf = ::Parser::Source::Buffer.new(filename, source: source)

        # Normalise s-exprs before comparison to paper over known
        # asymmetries between Parser::Ruby40 (under modernize) and
        # Prism::Translation::Parser40 (which doesn't fully honor
        # modernize):
        #   procarg0(:x) ↔ procarg0(arg(:x))       (post-modernize flag)
        #   lambda       ↔ send(nil, :lambda)      (`->` modernize form)
        # These are translation-layer gaps, not Frozone bugs, but the
        # bare equality check is order-dependent because WqParser
        # mutates Parser::Builders::Default globals at first use.
        # Pin the flags here AND normalise the comparison.
        ::Parser::Builders::Default.modernize
        prev_procarg0 = ::Parser::Builders::Default.emit_arg_inside_procarg0
        ::Parser::Builders::Default.emit_arg_inside_procarg0 = true

        ast_primary = nil
        errors_primary = []
        begin
          parser_a = ::Parser::Ruby40.new
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

        # Restore — production WqParser usage relies on emit_arg_inside_procarg0=false.
        ::Parser::Builders::Default.emit_arg_inside_procarg0 = prev_procarg0

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
