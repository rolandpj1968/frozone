$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

a = [10, 20, 30, 40, 50]
puts a.size
puts a[0]
puts a[2]
puts a[-1]
a.push(99)
puts a.size
puts a[5]
puts a.first
puts a.last
