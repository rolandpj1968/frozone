$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

rng = Random.new(42)
5.times do
  puts rng.rand
end
