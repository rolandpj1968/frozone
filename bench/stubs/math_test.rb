$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

puts Math.sqrt(16) == 4.0
puts Math.sqrt(2) > 1.4 && Math.sqrt(2) < 1.5
puts Math.cbrt(27) > 2.99 && Math.cbrt(27) < 3.01
puts Math.exp(0) == 1.0
puts Math.log(1) == 0.0
puts Math.log10(1000) == 3.0
puts Math.log2(8) == 3.0
puts Math.sin(0) == 0.0
puts Math.cos(0) == 1.0
puts (Math.atan2(1, 1) * 4 - Math::PI).abs < 0.001
puts Math.hypot(3, 4) == 5.0
puts Math::PI > 3.14 && Math::PI < 3.15
puts Math::E > 2.71 && Math::E < 2.72
puts Math.sqrt(4.0) == 2.0
puts Math.sqrt(9) == 3.0
