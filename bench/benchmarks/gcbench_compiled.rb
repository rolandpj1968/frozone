# GCBench adapted for compilation — top-level functions instead of class methods.

require_relative '../harness/loader'

class GCNode
  attr_accessor :left, :right, :i, :j

  def initialize(left = nil, right = nil)
    @left = left
    @right = right
    @i = 0
    @j = 0
  end
end

STRETCH_TREE_DEPTH    = 18
LONG_LIVED_TREE_DEPTH = 16
MIN_TREE_DEPTH        = 4
MAX_TREE_DEPTH        = 16

def gc_tree_size(depth)
  (1 << (depth + 1)) - 1
end

def gc_num_iters(depth)
  2 * gc_tree_size(STRETCH_TREE_DEPTH) / gc_tree_size(depth)
end

def gc_populate(depth, node)
  if depth > 0
    depth -= 1
    left = GCNode.new
    right = GCNode.new
    node.left = left
    node.right = right
    gc_populate(depth, left)
    gc_populate(depth, right)
  end
end

def gc_make_tree(depth)
  if depth <= 0
    GCNode.new
  else
    GCNode.new(gc_make_tree(depth - 1), gc_make_tree(depth - 1))
  end
end

def gc_time_construction(depth)
  n = gc_num_iters(depth)
  n.times do
    node = GCNode.new
    gc_populate(depth, node)
  end
  n.times do
    gc_make_tree(depth)
  end
end

run_benchmark(10) do
  depth = MIN_TREE_DEPTH
  while depth <= MAX_TREE_DEPTH
    gc_time_construction(depth)
    depth += 2
  end
end
