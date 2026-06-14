$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

def my_top_method(x)
  x + 1
end

puts my_top_method(41)
