require 'frozone/vm/dual_parser'

RSpec.describe Frozone::Vm::DualParser do
  def parse(src)
    described_class.parse(src, filename: 'spec.rb')
  end

  describe '.parse' do
    it 'returns a Result struct' do
      expect(parse('1 + 2')).to be_a(described_class::Result)
    end

    it 'provides the AST from the primary parser' do
      result = parse('x = 42')
      expect(result.ast).not_to be_nil
      expect(result.ast.type).to eq(:lvasgn)
    end

    it 'provides the AST from the prism translation parser' do
      result = parse('x = 42')
      expect(result.ast_prism).not_to be_nil
      expect(result.ast_prism.type).to eq(:lvasgn)
    end
  end

  describe 'Result#agree?' do
    it 'returns true when both parsers produce the same AST' do
      expect(parse('x = 1 + 2').agree?).to be(true)
    end

    it 'returns true for method definitions' do
      src = 'def foo(a, b = 1, *rest, c:, d: 2, **kw, &blk); a + b; end'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for class definitions' do
      src = 'class Foo < Bar; def initialize(x); @x = x; end; end'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for blocks and closures' do
      src = '[1, 2, 3].map { |x| x * 2 }.select { |x| x > 1 }'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for conditionals' do
      src = 'if x > 0 then :pos elsif x < 0 then :neg else :zero end'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for rescue/ensure' do
      src = 'begin; raise "oops"; rescue RuntimeError => e; e.message; ensure; nil; end'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for lambdas' do
      src = 'f = ->(x, y) { x + y }'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for pattern matching' do
      src = 'case x; in [Integer => n, *] then n; else 0; end'
      expect(parse(src).agree?).to be(true)
    end

    it 'returns true for all Frozone core lib files' do
      Dir.glob(File.expand_path('../../../lib/core/**/*.rb', __dir__)).sort.each do |path|
        source = File.read(path)
        result = described_class.parse(source, filename: path)
        expect(result.agree?).to be(true), "parsers disagree on #{path}:\n#{result.diff}"
      end
    end
  end

  describe 'Result#diff' do
    it 'returns nil when parsers agree' do
      expect(parse('1 + 2').diff).to be_nil
    end
  end

  describe '.parse!' do
    it 'returns the result when parsers agree' do
      result = described_class.parse!('x = 1')
      expect(result).to be_a(described_class::Result)
      expect(result.agree?).to be(true)
    end
  end
end
