$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

# def with rest param — receives an Array
def collect(*items)
  items.size
end

# Method that uses items as Array (indexing)
def first_of(*items)
  items[0]
end

# ---- Execute ----
arr = [10, 20, 30, 40, 50]

# Call with explicit splat — passes the array as the rest
puts collect(*arr)        # 5
puts first_of(*arr)       # 10

# Different array
arr2 = [99, 100]
puts collect(*arr2)       # 2
puts first_of(*arr2)      # 99
