# Frozone benchmark harness — Crystal equivalent of bench/harness/harness.rb
# Included via compile.rb --bench flag; not part of the core runtime.

def run_benchmark(n : RubyObject, &block : -> RubyObject) : RubyNil
  t0 = Time.instant
  block.call
  elapsed = (Time.instant - t0).total_milliseconds
  puts "#{elapsed.round(2)} ms/iter"
  RUBY_NIL
end

def make_shareable(x : RubyObject) : RubyObject
  x
end
