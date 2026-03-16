module Enumerable
  def to_a
    r = []; each { |*x| r << (x.empty? ? nil : (x.length == 1 ? x[0] : x)) }; r
  end
  alias entries to_a

  def to_h(*args, &block)
    r = {}
    each(*args) do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      pair = block ? block.call(v) : v
      unless pair.is_a?(Array)
        if pair.respond_to?(:to_ary)
          pair = pair.to_ary
          raise TypeError, "wrong element type #{pair.class} (expected Array)" unless pair.is_a?(Array)
        else
          raise TypeError, "wrong element type #{pair.nil? ? 'NilClass' : pair.class} (expected Array)"
        end
      end
      raise ArgumentError, "element has wrong array length (expected 2, was #{pair.length})" unless pair.length == 2
      r[pair[0]] = pair[1]
    end
    r
  end

  def map(&block)
    return to_enum(:map) unless block
    r = []; each { |*x| r << block.call(*x) }; r
  end
  alias collect map

  def flat_map(&block)
    return to_enum(:flat_map) unless block
    r = []
    each { |*x|
      v = block.call(*x)
      if v.is_a?(Array)
        v.each { |e| r << e }
      elsif v.respond_to?(:to_ary)
        arr = v.to_ary
        if arr.nil?
          r << v
        elsif arr.is_a?(Array)
          arr.each { |e| r << e }
        else
          raise TypeError, "can't convert #{v.class} into Array (#{v.class}#to_ary gives #{arr.class})"
        end
      else
        r << v
      end
    }
    r
  end
  alias collect_concat flat_map

  def select(&block)
    return to_enum(:select) unless block
    r = []; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); r << v if block.call(*x) }; r
  end
  alias filter select
  alias find_all select

  def reject(&block)
    return to_enum(:reject) unless block
    r = []; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); r << v unless block.call(*x) }; r
  end

  def find(ifnone = nil, &block)
    return to_enum(:find, ifnone) unless block
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return v if block.call(*x) }
    ifnone ? ifnone.call : nil
  end
  alias detect find

  def find_index(val = :__none__, &block)
    if block
      i = 0; each { |*x| return i if block.call(*x); i += 1 }; nil
    elsif val.equal?(:__none__)
      return to_enum(:find_index)
    else
      i = 0; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return i if v == val; i += 1 }; nil
    end
  end

  def include?(val)
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return true if v == val }
    false
  end
  alias member? include?

  def any?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return true if (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return true if pat === v }
    end
    false
  end

  def all?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return false unless (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return false unless pat === v }
    end
    true
  end

  def none?(pat = :__none__, &block)
    if pat.equal?(:__none__)
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return false if (block ? block.call(*x) : v) }
    else
      warn "warning: given block not used" if block
      each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); return false if pat === v }
    end
    true
  end

  def one?(pat = :__none__, &block)
    found = false
    if pat.equal?(:__none__)
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if block ? block.call(*x) : v
          return false if found
          found = true
        end
      end
    else
      warn "warning: given block not used" if block
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if pat === v
          return false if found
          found = true
        end
      end
    end
    found
  end

  def count(val = :__none__, &block)
    if val.equal?(:__none__)
      return to_a.length unless block
      n = 0; each { |*x| n += 1 if block.call(*x) }; n
    else
      warn "warning: given block not used" if block
      n = 0; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); n += 1 if v == val }; n
    end
  end

  def reduce(*args, &block)
    # Resolve (initial, sym/str) from args
    sym = nil; has_initial = false; initial = nil
    case args.length
    when 0
      raise ArgumentError, "no block given (yield)" unless block
    when 1
      if args[0].is_a?(Symbol) || args[0].is_a?(String)
        sym = args[0].to_sym
        warn "warning: given block not used" if block
      else
        has_initial = true; initial = args[0]
        raise ArgumentError, "no block given (yield)" unless block
      end
    when 2
      initial = args[0]; has_initial = true
      arg1 = args[1]
      if arg1.is_a?(Symbol)
        sym = arg1.to_sym
      elsif arg1.is_a?(String)
        sym = arg1.to_sym
      elsif arg1.respond_to?(:to_str)
        sym = arg1.to_str.to_sym
      else
        raise TypeError, "#{arg1.inspect} is not a symbol nor a string"
      end
      warn "warning: given block not used" if block
    else
      raise ArgumentError, "wrong number of arguments (given #{args.length}, expected 0..2)"
    end
    acc = initial; first = !has_initial
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      if first
        acc = v; first = false
      elsif sym
        acc = acc.send(sym, v)
      else
        acc = block.call(acc, v)
      end
    end
    acc
  end
  alias inject reduce

  def sum(initial = 0)
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); initial = initial + v }
    initial
  end

  def min(n = nil, &block)
    if n
      sort_by { |x| x }.first(n)
    else
      result = nil; first = true
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if first
          result = v; first = false
        elsif block
          result = v if block.call(v, result) < 0
        else
          result = v if (v <=> result) < 0
        end
      end
      result
    end
  end

  def max(n = nil, &block)
    if n
      sort_by { |x| x }.last(n)
    else
      result = nil; first = true
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if first
          result = v; first = false
        elsif block
          result = v if block.call(v, result) > 0
        else
          result = v if (v <=> result) > 0
        end
      end
      result
    end
  end

  def min_by(n = nil, &block)
    return to_enum(:min_by) unless block
    if n
      sort_by(&block).first(n)
    else
      best = nil; best_key = nil; first = true
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        k = block.call(v)
        if first || (k <=> best_key) < 0
          best = v; best_key = k; first = false
        end
      end
      best
    end
  end

  def max_by(n = nil, &block)
    return to_enum(:max_by) unless block
    if n
      sort_by(&block).last(n)
    else
      best = nil; best_key = nil; first = true
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        k = block.call(v)
        if first || (k <=> best_key) > 0
          best = v; best_key = k; first = false
        end
      end
      best
    end
  end

  def minmax(&block)
    min_val = nil; max_val = nil; first = true
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      if first
        min_val = max_val = v; first = false
      elsif block
        min_val = v if block.call(v, min_val) < 0
        max_val = v if block.call(v, max_val) > 0
      else
        min_val = v if (v <=> min_val) < 0
        max_val = v if (v <=> max_val) > 0
      end
    end
    [min_val, max_val]
  end

  def minmax_by(&block)
    return to_enum(:minmax_by) unless block
    min_val = nil; max_val = nil; min_key = nil; max_key = nil; first = true
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      k = block.call(v)
      if first
        min_val = max_val = v; min_key = max_key = k; first = false
      else
        if (k <=> min_key) < 0; min_val = v; min_key = k; end
        if (k <=> max_key) > 0; max_val = v; max_key = k; end
      end
    end
    [min_val, max_val]
  end

  def sort(&block)
    to_a.sort(&block)
  end

  def sort_by(&block)
    return to_enum(:sort_by) unless block
    to_a.sort_by(&block)
  end

  def each_with_index(&block)
    return to_enum(:each_with_index) unless block
    i = 0
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      block.call(v, i); i += 1
    end
    self
  end

  def each_with_object(obj, &block)
    return to_enum(:each_with_object, obj) unless block
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      block.call(v, obj)
    end
    obj
  end

  def each_slice(n, &block)
    return to_enum(:each_slice, n) unless block
    buf = []
    each do |*x|
      buf << (x.empty? ? nil : (x.length == 1 ? x[0] : x))
      if buf.length == n
        block.call(buf); buf = []
      end
    end
    block.call(buf) unless buf.empty?
    nil
  end

  def each_cons(n, &block)
    return to_enum(:each_cons, n) unless block
    buf = []
    each do |*x|
      buf << (x.empty? ? nil : (x.length == 1 ? x[0] : x))
      buf.shift if buf.length > n
      block.call(buf.dup) if buf.length == n
    end
    nil
  end

  def zip(*others)
    arrays = others.map { |o| o.respond_to?(:to_ary) ? o.to_ary : o.to_a }
    result = []
    i = 0
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      row = [v]
      arrays.each { |a| row << (i < a.length ? a[i] : nil) }
      if block_given?
        yield row
      else
        result << row
      end
      i += 1
    end
    block_given? ? nil : result
  end

  def group_by(&block)
    return to_enum(:group_by) unless block
    result = {}
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      k = block.call(v); result[k] ||= []; result[k] << v
    end
    result
  end

  def tally(hash = nil)
    result = hash || {}
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); result[v] = (result[v] || 0) + 1 }
    result
  end

  def grep(pattern, &block)
    r = []
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      if pattern === v
        r << (block ? block.call(v) : v)
      end
    end
    r
  end

  def grep_v(pattern, &block)
    r = []
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      unless pattern === v
        r << (block ? block.call(v) : v)
      end
    end
    r
  end

  def first(n = :__none__)
    if n.equal?(:__none__)
      each { |*x| return x.empty? ? nil : (x.length == 1 ? x[0] : x) }
      nil
    else
      r = []; i = 0
      each { |*x| break if i >= n; r << (x.empty? ? nil : (x.length == 1 ? x[0] : x)); i += 1 }
      r
    end
  end

  def take(n)
    r = []; i = 0
    each { |*x| break if i >= n; r << (x.empty? ? nil : (x.length == 1 ? x[0] : x)); i += 1 }
    r
  end

  def take_while(&block)
    return to_enum(:take_while) unless block
    r = []; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); break unless block.call(*x); r << v }; r
  end

  def drop(n)
    r = []; i = 0
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); i < n ? (i += 1) : (r << v) }
    r
  end

  def drop_while(&block)
    return to_enum(:drop_while) unless block
    r = []; dropping = true
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      dropping = false if dropping && !block.call(*x)
      r << v unless dropping
    end
    r
  end

  def uniq(&block)
    seen = {}; r = []
    each do |*x|
      v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
      k = block ? block.call(v) : v
      r << v and seen[k] = true unless seen.key?(k)
    end
    r
  end

  def chunk(&block)
    return to_enum(:chunk) unless block
    Enumerator.new do |y|
      last_key = nil; has_key = false; buf = []
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        k = block.call(v)
        if k.nil? || k == :_separator
          y << [last_key, buf] if has_key && !buf.empty?
          has_key = false; last_key = nil; buf = []
        elsif k.is_a?(Symbol) && k.to_s[0] == '_' && k != :_alone
          raise RuntimeError, "chunk doesn't accept special symbol #{k.inspect}"
        elsif k == :_alone
          y << [last_key, buf] if has_key && !buf.empty?
          y << [:_alone, [v]]
          has_key = false; last_key = nil; buf = []
        elsif !has_key || k != last_key
          y << [last_key, buf] if has_key && !buf.empty?
          last_key = k; has_key = true; buf = [v]
        else
          buf << v
        end
      end
      y << [last_key, buf] if has_key && !buf.empty?
    end
  end

  def chunk_while(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if buf.nil?
          buf = [v]
        elsif block.call(buf.last, v)
          buf << v
        else
          y << buf; buf = [v]
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def slice_when(&block)
    raise ArgumentError, "tried to create Proc object without a block" unless block
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if buf.nil?
          buf = [v]
        elsif block.call(buf.last, v)
          y << buf; buf = [v]
        else
          buf << v
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def filter_map(&block)
    return to_enum(:filter_map) unless block
    r = []
    each { |*x| v = block.call(*x); r << v if v }
    r
  end

  def compact
    r = []; each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); r << v unless v.nil? }; r
  end

  def each_entry(*args, &block)
    return to_enum(:each_entry, *args) unless block
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); block.call(v) }
    self
  end

  def reverse_each(&block)
    return to_enum(:reverse_each) unless block
    to_a.reverse.each { |x| block.call(x) }
    self
  end

  def partition(&block)
    return to_enum(:partition) unless block
    yes = []; no = []
    each { |*x| v = x.empty? ? nil : (x.length == 1 ? x[0] : x); (block.call(*x) ? yes : no) << v }
    [yes, no]
  end

  def cycle(n = nil, &block)
    return to_enum(:cycle, n) unless block
    elems = to_a
    return nil if elems.empty?
    if n.nil?
      loop { elems.each { |v| block.call(v) } }
    else
      n = n.respond_to?(:to_int) ? n.to_int : n.to_i
      return nil if n <= 0
      n.times { elems.each { |v| block.call(v) } }
    end
    nil
  end

  def slice_before(pat = :__none__, &block)
    if pat.equal?(:__none__)
      raise ArgumentError, "tried to create Proc object without a block" unless block
    else
      raise ArgumentError, "wrong number of arguments (given 2, expected 1)" if block
      block = proc { |x| pat === x }
    end
    Enumerator.new do |y|
      buf = nil
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        if block.call(v)
          y << buf if buf && !buf.empty?
          buf = [v]
        else
          buf ||= []
          buf << v
        end
      end
      y << buf if buf && !buf.empty?
    end
  end

  def slice_after(pat = :__none__, &block)
    if pat.equal?(:__none__)
      raise ArgumentError, "tried to create Proc object without a block" unless block
    else
      raise ArgumentError, "wrong number of arguments (given 2, expected 1)" if block
      block = proc { |x| pat === x }
    end
    Enumerator.new do |y|
      buf = []
      each do |*x|
        v = x.empty? ? nil : (x.length == 1 ? x[0] : x)
        buf << v
        if block.call(v)
          y << buf
          buf = []
        end
      end
      y << buf unless buf.empty?
    end
  end

  def to_set(klass = Set, *args, &block)
    warn "#{caller(0, 1)[0]}: warning: Enumerable#to_set is deprecated and will be removed in Ruby 4.2." if klass == Set
    klass.new(self, *args, &block)
  end

  def chain(*enums)
    Enumerator::Chain.new(self, *enums)
  end
  alias + chain
end
