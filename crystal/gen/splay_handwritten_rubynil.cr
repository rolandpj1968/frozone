# Variant: same algorithm as splay_handwritten.cr, but uses Frozone-style
# `RubyNil` class instead of Crystal `Nil` for nullable refs.
# Isolates: how much of the 5.5x gap is RubyNil-as-class vs Crystal-Nil?

abstract class RubyObject
  def truthy?
    true
  end
end

class RubyNil < RubyObject
  def truthy?
    false
  end
end

RUBY_NIL = RubyNil.new

class SplayNode < RubyObject
  property key : Float64
  property value : Payload
  @left : SplayNode | RubyNil = RUBY_NIL
  @right : SplayNode | RubyNil = RUBY_NIL

  def initialize(@key, @value); end

  def left : SplayNode | RubyNil; @left; end
  def right : SplayNode | RubyNil; @right; end
  def left=(v : RubyObject); @left = v.as(SplayNode | RubyNil); v; end
  def right=(v : RubyObject); @right = v.as(SplayNode | RubyNil); v; end
end

abstract class Payload < RubyObject
end

class PayloadNode < Payload
  property pleft : Payload
  property pright : Payload
  def initialize(@pleft, @pright); end
end

class PayloadLeaf < Payload
  property array : Array(Int32)
  property string : String
  def initialize(@array, @string); end
end

class SplayTree
  @root : SplayNode | RubyNil = RUBY_NIL

  def empty?
    @root.is_a?(RubyNil)
  end

  def insert(key : Float64, value : Payload)
    if empty?
      @root = SplayNode.new(key, value)
      return
    end
    splay!(key)
    return if @root.as(SplayNode).key == key
    node = SplayNode.new(key, value)
    if key > @root.as(SplayNode).key
      node.left = @root
      node.right = @root.as(SplayNode).right
      @root.as(SplayNode).right = RUBY_NIL
    else
      node.right = @root
      node.left = @root.as(SplayNode).left
      @root.as(SplayNode).left = RUBY_NIL
    end
    @root = node
  end

  def remove(key : Float64)
    raise "Key not found" if empty?
    splay!(key)
    raise "Key not found" if @root.as(SplayNode).key != key
    removed = @root.as(SplayNode)
    if @root.as(SplayNode).left.is_a?(RubyNil)
      @root = @root.as(SplayNode).right
    else
      right = @root.as(SplayNode).right
      @root = @root.as(SplayNode).left
      splay!(key)
      @root.as(SplayNode).right = right
    end
    removed
  end

  def find(key : Float64) : SplayNode | RubyNil
    return RUBY_NIL if empty?
    splay!(key)
    @root.as(SplayNode).key == key ? @root : RUBY_NIL
  end

  def find_max(start_node : RubyObject = RUBY_NIL) : SplayNode | RubyNil
    return RUBY_NIL if empty?
    current : SplayNode | RubyNil = start_node.is_a?(RubyNil) ? @root : start_node
    while current.as(SplayNode).right.truthy?
      current = current.as(SplayNode).right
    end
    current
  end

  def find_greatest_less_than(key : Float64) : SplayNode | RubyNil
    return RUBY_NIL if empty?
    splay!(key)
    if @root.as(SplayNode).key < key
      @root
    elsif @root.as(SplayNode).left.truthy?
      find_max(@root.as(SplayNode).left)
    else
      RUBY_NIL
    end
  end

  private def splay!(key : Float64)
    return if empty?
    dummy : SplayNode = SplayNode.new(0.0, PayloadLeaf.new([] of Int32, ""))
    left : SplayNode | RubyNil = dummy
    right : SplayNode | RubyNil = dummy
    current : SplayNode | RubyNil = @root
    loop do
      if key < current.as(SplayNode).key
        break unless current.as(SplayNode).left.truthy?
        if key < current.as(SplayNode).left.as(SplayNode).key
          tmp = current.as(SplayNode).left
          current.as(SplayNode).left = tmp.as(SplayNode).right
          tmp.as(SplayNode).right = current
          current = tmp
          break unless current.as(SplayNode).left.truthy?
        end
        right.as(SplayNode).left = current
        right = current
        current = current.as(SplayNode).left
      elsif key > current.as(SplayNode).key
        break unless current.as(SplayNode).right.truthy?
        if key > current.as(SplayNode).right.as(SplayNode).key
          tmp = current.as(SplayNode).right
          current.as(SplayNode).right = tmp.as(SplayNode).left
          tmp.as(SplayNode).left = current
          current = tmp
          break unless current.as(SplayNode).right.truthy?
        end
        left.as(SplayNode).right = current
        left = current
        current = current.as(SplayNode).right
      else
        break
      end
    end
    left.as(SplayNode).right = current.as(SplayNode).left
    right.as(SplayNode).left = current.as(SplayNode).right
    current.as(SplayNode).left = dummy.right
    current.as(SplayNode).right = dummy.left
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
    next if tree.find(key).truthy?
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
    if greatest.truthy?
      tree.remove(greatest.as(SplayNode).key)
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
puts "splay handwritten rubynil: #{elapsed.total_seconds.round(3)}s"
