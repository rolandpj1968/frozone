$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(n, &); n.times { yield }; end
require_relative '../benchmarks/binarytrees_nosplat'

# Under --aot, everything below is compiled to Crystal.
# Correctness check
total_check = 0
depth = MIN_DEPTH
while depth <= MAX_DEPTH
  iterations = 2**(MAX_DEPTH - depth + MIN_DEPTH)
  check = 0
  for i in 1..iterations
    temp_tree = bottom_up_tree(depth)
    check += item_check(temp_tree[0], temp_tree[1])
  end
  total_check += check
  depth += 2
end
raise "binarytrees: got #{total_check}, expected 3123888" unless total_check == 3123888

run_benchmark(60) do
  stretch_tree = bottom_up_tree(STRETCH_DEPTH)
  stretch_tree = nil

  long_lived_tree = bottom_up_tree(MAX_DEPTH)

  depth = MIN_DEPTH
  while depth <= MAX_DEPTH
    iterations = 2**(MAX_DEPTH - depth + MIN_DEPTH)
    check = 0
    for i in 1..iterations
      temp_tree = bottom_up_tree(depth)
      check += item_check(temp_tree[0], temp_tree[1])
    end
    depth += 2
  end
end
