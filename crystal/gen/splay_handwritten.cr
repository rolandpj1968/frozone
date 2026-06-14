# Hand-written pure-Crystal port of bench/benchmarks/splay.rb
# No Frozone object model — plain classes, Float64 keys, Crystal Nil for nullable refs.
# Goal: measure the floor for this algorithm under Crystal --release.

class SplayNode
  property key : Float64
  property value : Payload
  property left : SplayNode?
  property right : SplayNode?

  def initialize(@key, @value)
    @left = nil
    @right = nil
  end
end

# Payload is a recursive tree of PayloadNode, bottoming out in Leaf.
abstract class Payload
end

class PayloadNode < Payload
  property left : Payload
  property right : Payload
  def initialize(@left, @right); end
end

class PayloadLeaf < Payload
  property array : Array(Int32)
  property string : String
  def initialize(@array, @string); end
end

class SplayTree
  @root : SplayNode?

  def initialize
    @root = nil
  end

  def empty?
    @root.nil?
  end

  def insert(key : Float64, value : Payload)
    if (r = @root).nil?
      @root = SplayNode.new(key, value)
      return
    end
    splay!(key)
    r = @root.not_nil!
    return if r.key == key
    node = SplayNode.new(key, value)
    if key > r.key
      node.left = r
      node.right = r.right
      r.right = nil
    else
      node.right = r
      node.left = r.left
      r.left = nil
    end
    @root = node
  end

  def remove(key : Float64)
    raise "Key not found" if empty?
    splay!(key)
    r = @root.not_nil!
    raise "Key not found" if r.key != key
    removed = r
    if r.left.nil?
      @root = r.right
    else
      right = r.right
      @root = r.left
      splay!(key)
      @root.not_nil!.right = right
    end
    removed
  end

  def find(key : Float64) : SplayNode?
    return nil if empty?
    splay!(key)
    r = @root.not_nil!
    r.key == key ? r : nil
  end

  def find_max(start_node : SplayNode? = nil) : SplayNode?
    return nil if empty?
    current = start_node || @root.not_nil!
    while (rt = current.right)
      current = rt
    end
    current
  end

  def find_greatest_less_than(key : Float64) : SplayNode?
    return nil if empty?
    splay!(key)
    r = @root.not_nil!
    if r.key < key
      r
    elsif (l = r.left)
      find_max(l)
    end
  end

  private def splay!(key : Float64)
    return if (root = @root).nil?
    dummy = SplayNode.new(0.0, PayloadLeaf.new([] of Int32, ""))
    left = dummy
    right = dummy
    current = root
    loop do
      if key < current.key
        cl = current.left
        break if cl.nil?
        if key < cl.key
          current.left = cl.right
          cl.right = current
          current = cl
          cl2 = current.left
          break if cl2.nil?
        end
        right.left = current
        right = current
        nxt = current.left
        break if nxt.nil?
        current = nxt
      elsif key > current.key
        cr = current.right
        break if cr.nil?
        if key > cr.key
          current.right = cr.left
          cr.left = current
          current = cr
          cr2 = current.right
          break if cr2.nil?
        end
        left.right = current
        left = current
        nxt = current.right
        break if nxt.nil?
        current = nxt
      else
        break
      end
    end
    left.right = current.left
    right.left = current.right
    current.left = dummy.right
    current.right = dummy.left
    @root = current
  end
end

TREE_SIZE     = 8000
MODIFICATIONS = 80
PAYLOAD_DEPTH = 5

def generate_payload(depth : Int32, tag : String) : Payload
  if depth == 0
    PayloadLeaf.new([0, 1, 2, 3, 4, 5, 6, 7, 8, 9], "String for key #{tag} in leaf node")
  else
    PayloadNode.new(
      generate_payload(depth - 1, tag),
      generate_payload(depth - 1, tag)
    )
  end
end

def insert_new_node(tree : SplayTree, rng : Random) : Float64
  loop do
    key = rng.rand
    next if tree.find(key)
    tree.insert(key, generate_payload(PAYLOAD_DEPTH, key.to_s))
    return key
  end
end

def splay_setup(rng : Random) : SplayTree
  tree = SplayTree.new
  TREE_SIZE.times { insert_new_node(tree, rng) }
  tree
end

def splay_run(tree : SplayTree, rng : Random)
  MODIFICATIONS.times do
    key = insert_new_node(tree, rng)
    greatest = tree.find_greatest_less_than(key)
    if greatest
      tree.remove(greatest.key)
    else
      tree.remove(key)
    end
  end
end

rng = Random.new(42_u64)
tree = splay_setup(rng)

t0 = Time.monotonic
200.times do
  50.times { splay_run(tree, rng) }
end
elapsed = Time.monotonic - t0
puts "splay handwritten: #{elapsed.total_seconds.round(3)}s"
