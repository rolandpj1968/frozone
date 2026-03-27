# Binary trees benchmark without splat (for compiler compatibility)
# Same algorithm as binarytrees/benchmark.rb but uses explicit indexing.

def item_check(left, right)
  return 1 if left.nil?
  1 + item_check(left[0], left[1]) + item_check(right[0], right[1])
end

def bottom_up_tree(depth)
  return [nil, nil] unless depth > 0
  depth -= 1
  [bottom_up_tree(depth), bottom_up_tree(depth)]
end

MAX_DEPTH = 14
MIN_DEPTH = 4

MAX_DEPTH = MIN_DEPTH + 2 if MIN_DEPTH + 2 > MAX_DEPTH
STRETCH_DEPTH = MAX_DEPTH + 1

require_relative '../harness/loader'

run_benchmark(60) do
  stretch_tree = bottom_up_tree(STRETCH_DEPTH)
  stretch_tree = nil

  long_lived_tree = bottom_up_tree(MAX_DEPTH)

  MIN_DEPTH.step(MAX_DEPTH, 2) do |depth|
    iterations = 2**(MAX_DEPTH - depth + MIN_DEPTH)
    check = 0
    for i in 1..iterations
      temp_tree = bottom_up_tree(depth)
      check += item_check(temp_tree[0], temp_tree[1])
    end
  end
end
