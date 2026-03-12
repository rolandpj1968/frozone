require_relative '../../support/vm_loader'

# These tests assert that the parser produces well-typed AST structures for
# the constructs that Utils.rb check_* methods were guarding against. They
# replace the runtime checks as the authoritative correctness assertion.

RSpec.describe Frozone::Vm::Parser do
  def parse(code)
    Frozone::Vm::Parser.new(code).ast
  end

  def parse_method(code)
    node = parse(code)
    node = node.instance_variable_get(:@nodes).first if node.is_a?(Frozone::Ast::Sequence)
    node
  end

  def parse_block(code)
    parse_method(code).block_node
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Method parameter shapes
  # ──────────────────────────────────────────────────────────────────────────

  describe "method params" do
    it "required params are Symbols" do
      m = parse_method("def foo(a, b, c); end")
      expect(m).to be_a(Frozone::Ast::MethodDef)
      expect(m.required_params).to eq([:a, :b, :c])
      expect(m.required_params).to all(be_a(Symbol))
    end

    it "optional params are [Symbol, Node] pairs" do
      m = parse_method("def foo(a = 1, b = 'x'); end")
      expect(m.optional_params.length).to eq(2)
      m.optional_params.each do |pair|
        expect(pair).to be_a(Array)
        expect(pair.length).to eq(2)
        expect(pair[0]).to be_a(Symbol)
        expect(pair[1]).to be_a(Frozone::Ast::Node)
      end
      expect(m.optional_params.map(&:first)).to eq([:a, :b])
    end

    it "rest param is a Symbol" do
      m = parse_method("def foo(*args); end")
      expect(m.rest_param).to be_a(Symbol)
      expect(m.rest_param).to eq(:args)
    end

    it "anonymous rest param gets synthetic name" do
      m = parse_method("def foo(*); end")
      expect(m.rest_param).to eq(:__anon_rest__)
    end

    it "post params are Symbols" do
      m = parse_method("def foo(*args, x, y); end")
      expect(m.post_params).to eq([:x, :y])
      expect(m.post_params).to all(be_a(Symbol))
    end

    it "required keyword params are Symbols" do
      m = parse_method("def foo(x:, y:); end")
      expect(m.required_kw_params).to eq([:x, :y])
      expect(m.required_kw_params).to all(be_a(Symbol))
    end

    it "optional keyword params are [Symbol, Node] pairs" do
      m = parse_method("def foo(x: 1, y: 'z'); end")
      expect(m.optional_kw_params.length).to eq(2)
      m.optional_kw_params.each do |pair|
        expect(pair).to be_a(Array)
        expect(pair.length).to eq(2)
        expect(pair[0]).to be_a(Symbol)
        expect(pair[1]).to be_a(Frozone::Ast::Node)
      end
      expect(m.optional_kw_params.map(&:first)).to eq([:x, :y])
    end

    it "keyword rest param is a Symbol" do
      m = parse_method("def foo(**opts); end")
      expect(m.kw_rest_param).to be_a(Symbol)
      expect(m.kw_rest_param).to eq(:opts)
    end

    it "**nil produces :__no_kwargs__" do
      m = parse_method("def foo(**nil); end")
      expect(m.kw_rest_param).to eq(:__no_kwargs__)
    end

    it "block param is a Symbol" do
      m = parse_method("def foo(&blk); end")
      expect(m.block_param).to be_a(Symbol)
      expect(m.block_param).to eq(:blk)
    end

    it "body is a Node" do
      m = parse_method("def foo; 42; end")
      expect(m.body).to be_a(Frozone::Ast::Node)
    end

    it "locals are all Symbols" do
      m = parse_method("def foo(a, b = 1, *c); x = 1; end")
      expect(m.locals).to all(be_a(Symbol))
    end

    it "method name is a Symbol" do
      m = parse_method("def my_method; end")
      expect(m.name).to be_a(Symbol)
      expect(m.name).to eq(:my_method)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Destructured (multi-target) params
  # ──────────────────────────────────────────────────────────────────────────

  describe "destructured params" do
    it "produces a Hash with :names, :rest, :rights keys" do
      m = parse_method("def foo((a, b)); end")
      d = m.required_params.first
      expect(d).to be_a(Hash)
      expect(d.keys).to include(:names, :rest, :rights)
    end

    it ":names contains Symbols" do
      m = parse_method("def foo((a, b, c)); end")
      d = m.required_params.first
      expect(d[:names]).to eq([:a, :b, :c])
      expect(d[:names]).to all(be_a(Symbol))
    end

    it ":rest is a Symbol when present" do
      m = parse_method("def foo((a, *b, c)); end")
      d = m.required_params.first
      expect(d[:rest]).to eq(:b)
    end

    it ":rest is nil when absent" do
      m = parse_method("def foo((a, b)); end")
      d = m.required_params.first
      expect(d[:rest]).to be_nil
    end

    it ":rights contains post-rest Symbols" do
      m = parse_method("def foo((a, *b, c, d)); end")
      d = m.required_params.first
      expect(d[:rights]).to eq([:c, :d])
    end

    it "nested destructuring produces nested Hashes" do
      m = parse_method("def foo((a, (b, c))); end")
      d = m.required_params.first
      expect(d[:names][0]).to eq(:a)
      expect(d[:names][1]).to be_a(Hash)
      expect(d[:names][1][:names]).to eq([:b, :c])
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Block params
  # ──────────────────────────────────────────────────────────────────────────

  describe "block params" do
    it "required block params are Symbols" do
      b = parse_block("[].each { |a, b| }")
      expect(b.required_params).to eq([:a, :b])
      expect(b.required_params).to all(be_a(Symbol))
    end

    it "optional block params are [Symbol, Node] pairs" do
      b = parse_block("[].each { |a, b = 1| }")
      expect(b.optional_params.length).to eq(1)
      expect(b.optional_params[0][0]).to eq(:b)
      expect(b.optional_params[0][1]).to be_a(Frozone::Ast::Node)
    end

    it "block locals are all Symbols" do
      b = parse_block("[].each { |a, b| x = 1 }")
      expect(b.locals).to all(be_a(Symbol))
    end

    it "block body is a Node" do
      b = parse_block("[].each { |a| a + 1 }")
      expect(b.body).to be_a(Frozone::Ast::Node)
    end

    it "auto_splat is true for multi-param blocks" do
      b = parse_block("[].each { |a, b| }")
      expect(b.auto_splat).to be true
    end

    it "auto_splat is false for single-param blocks" do
      b = parse_block("[].each { |a| }")
      expect(b.auto_splat).to be false
    end

    it "auto_splat is false for rest-only blocks" do
      b = parse_block("[].each { |*a| }")
      expect(b.auto_splat).to be false
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Forwarding params
  # ──────────────────────────────────────────────────────────────────────────

  describe "forwarding params (...)" do
    it "produces synthetic forward names" do
      m = parse_method("def foo(...); end")
      expect(m.rest_param).to eq(:__forward_args__)
      expect(m.kw_rest_param).to eq(:__forward_kwargs__)
      expect(m.block_param).to eq(:__forward_block__)
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Method call kw_arg_nodes
  # ──────────────────────────────────────────────────────────────────────────

  describe "method call kw_arg_nodes" do
    it "kw_arg_nodes keys and values are Nodes" do
      call = parse_method("foo(x: 1, y: 'z')")
      expect(call).to be_a(Frozone::Ast::MethodCall)
      call.kw_arg_nodes.each do |k, v|
        expect(k).to be_a(Frozone::Ast::Node)
        expect(v).to be_a(Frozone::Ast::Node)
      end
    end

    it "kw_arg_nodes keys are SymbolLiterals" do
      call = parse_method("foo(x: 1, y: 2)")
      keys = call.kw_arg_nodes.keys
      expect(keys).to all(be_a(Frozone::Ast::SymbolLiteral))
      expect(keys.map(&:value)).to eq([:x, :y])
    end

    it "arg_nodes are all Nodes" do
      call = parse_method("foo(1, 'two', :three)")
      expect(call.arg_nodes).to all(be_a(Frozone::Ast::Node))
    end
  end

  # ──────────────────────────────────────────────────────────────────────────
  # Complex combined signature
  # ──────────────────────────────────────────────────────────────────────────

  describe "complex method signature" do
    it "all param categories have correct types" do
      m = parse_method("def foo(a, b = 1, *c, d, e:, f: 2, **g, &h); end")
      expect(m.required_params).to eq([:a])
      expect(m.optional_params.map(&:first)).to eq([:b])
      expect(m.optional_params[0][1]).to be_a(Frozone::Ast::Node)
      expect(m.rest_param).to eq(:c)
      expect(m.post_params).to eq([:d])
      expect(m.required_kw_params).to eq([:e])
      expect(m.optional_kw_params.map(&:first)).to eq([:f])
      expect(m.optional_kw_params[0][1]).to be_a(Frozone::Ast::Node)
      expect(m.kw_rest_param).to eq(:g)
      expect(m.block_param).to eq(:h)
    end
  end
end
