require 'tmpdir'

FROZONE_CPP_BIN = File.expand_path('../../bin/frozone-cpp', __dir__)

# Wire `bin/frozone-cpp <script>` into rspec. Several regression
# surfaces (NA-overload-resolution drift, kw_unset signature
# mismatches, leaf-dispatch + ProcN interactions) only surface here,
# not in integration_spec. The binary is expected to be pre-built —
# this spec skips politely if absent rather than triggering a
# 45-minute build.
RSpec.describe 'bin/frozone-cpp self-host smoke', if: File.executable?(FROZONE_CPP_BIN) do
  it 'runs a one-line puts script' do
    Dir.mktmpdir do |d|
      script = File.join(d, 'smoke.rb')
      File.write(script, 'puts "frozone-smoke-ok"')
      out = IO.popen([FROZONE_CPP_BIN, script], &:read)
      status = $?.exitstatus
      expect(status).to eq(0), "frozone-cpp exited #{status}, stdout=#{out.inspect}"
      expect(out.chomp).to eq('frozone-smoke-ok')
    end
  end

  it 'runs arithmetic + string interpolation' do
    Dir.mktmpdir do |d|
      script = File.join(d, 'smoke.rb')
      File.write(script, 'x = 1 + 2; puts "x=#{x}"')
      out = IO.popen([FROZONE_CPP_BIN, script], &:read)
      status = $?.exitstatus
      expect(status).to eq(0), "frozone-cpp exited #{status}, stdout=#{out.inspect}"
      expect(out.chomp).to eq('x=3')
    end
  end

  it 'runs a class definition + method call (op_eq_q path)' do
    Dir.mktmpdir do |d|
      script = File.join(d, 'smoke.rb')
      File.write(script, <<~RUBY)
        class Foo
          def initialize(n); @n = n; end
          def ==(other); other.is_a?(Foo) && @n == other.instance_variable_get(:@n); end
        end
        a, b = Foo.new(7), Foo.new(7)
        puts((a == b) ? "eq" : "neq")
      RUBY
      out = IO.popen([FROZONE_CPP_BIN, script], &:read)
      status = $?.exitstatus
      expect(status).to eq(0), "frozone-cpp exited #{status}, stdout=#{out.inspect}"
      expect(out.chomp).to eq('eq')
    end
  end
end
