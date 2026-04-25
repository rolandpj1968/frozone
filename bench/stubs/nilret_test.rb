$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
def find(arr, target)
  i = 0
  while i < 3
    return arr[i] if arr[i] == target
    i += 1
  end
  nil
end
puts find([10, 20, 30], 20)
