class Struct
  include Enumerable

  def self.new(*members, keyword_init: nil, &block)
    # Determine optional constant name from first argument
    const_name = if members.first.nil?
      members.shift  # nil → anonymous struct
      nil
    elsif members.first.is_a?(String)
      members.shift
    elsif members.first.respond_to?(:to_str)
      members.shift.to_str
    end

    # Validate members: only Symbol or String accepted (not arbitrary to_sym objects)
    seen = {}
    members.each do |m|
      unless m.is_a?(Symbol) || m.is_a?(String)
        raise TypeError, "#{m.inspect} is not a symbol nor a string"
      end
      sym = m.to_sym
      raise ArgumentError, "duplicate member: #{sym}" if seen[sym]
      seen[sym] = true
    end

    keyword_init_val = keyword_init

    klass = Class.new(self) do
      @members      = members.map(&:to_sym)
      @keyword_init = keyword_init_val

      # Override self.new so instance creation doesn't re-enter Struct.new
      def self.new(*args, **kwargs, &blk)
        obj = allocate
        obj.__send__(:initialize, *args, **kwargs)
        obj
      end

      # Generate reader/writer for each member; use lazy @struct_values so
      # subclass initialize can call setters before super.
      @members.each do |name|
        define_method(name)        { @struct_values&.fetch(name, nil) }
        define_method(:"#{name}=") do |v|
          raise FrozenError, "can't modify frozen #{self.class}" if frozen?
          (@struct_values ||= {})[name] = v
        end
      end

      def self.members = @members || superclass.members
      def self.[](*args, **kwargs, &blk) = new(*args, **kwargs, &blk)
      def self.keyword_init? = @keyword_init ? true : @keyword_init

      class_exec(self, &block) if block
    end

    self.const_set(const_name, klass) if const_name
    klass
  end
  # Struct#initialize is on the base class so subclasses can override it
  # and call super (matching MRI semantics).
  def self.members = []
  def members = self.class.members || []
  def to_a = members.map { |m| @struct_values&.fetch(m, nil) }
  def values = to_a
  def size = members.size
  alias length size
  def instance_variables = super.reject { |v| v == :@struct_values }

  def initialize(*args, **kwargs)
    mems = self.class.members || []
    @struct_values ||= {}
    if self.class.keyword_init?
      # Also accept a single Hash positional argument
      if args.size == 1 && args.first.is_a?(Hash) && kwargs.empty?
        kwargs = args.first.transform_keys(&:to_sym)
        args   = []
      end
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" unless args.empty?
      unknown = kwargs.keys - mems
      raise ArgumentError, "unknown keywords: #{unknown.map(&:to_s).join(', ')}" unless unknown.empty?
      mems.each { |m| @struct_values[m] = kwargs[m] }
    else
      if args.empty? && !kwargs.empty?
        # Ruby 3.2+: all-kwargs call → treat as member assignments
        mems.each { |m| @struct_values[m] = kwargs[m] }
      else
        # Mixed or all-positional: kwargs appended as a positional hash
        actual_args = kwargs.empty? ? args : args + [kwargs]
        raise ArgumentError, "struct size differs" if actual_args.size > mems.size
        mems.each_with_index { |m, i| @struct_values[m] = actual_args[i] }
      end
    end
  end
  alias deconstruct to_a

  def to_h(&block)
    h = {}
    members.each { |m| h[m] = @struct_values&.fetch(m, nil) }
    return h unless block
    result = {}
    h.each do |k, v|
      pair = block.call(k, v)
      pair = pair.to_ary if !pair.is_a?(Array) && pair.respond_to?(:to_ary)
      raise TypeError, "wrong element type #{pair.class} (expected Array)" unless pair.is_a?(Array)
      raise ArgumentError, "element has wrong array length (expected 2, was #{pair.length})" unless pair.length == 2
      result[pair[0]] = pair[1]
    end
    result
  end

  def deconstruct_keys(keys)
    raise TypeError, "expected Array or nil" unless keys.nil? || keys.is_a?(Array)
    return to_h if keys.nil?
    mems = members
    # More keys requested than attributes → no match possible
    return {} if keys.size > mems.size
    h = {}
    keys.each do |k|
      case k
      when Symbol
        return h unless mems.include?(k)
        h[k] = @struct_values&.fetch(k, nil)
      when String
        sym = k.to_sym
        return h unless mems.include?(sym)
        h[k] = @struct_values&.fetch(sym, nil)
      when Integer
        idx = k < 0 ? mems.size + k : k
        return h unless idx >= 0 && idx < mems.size
        h[k] = @struct_values&.fetch(mems[idx], nil)
      else
        unless k.respond_to?(:to_int)
          raise TypeError, "no implicit conversion of #{k.class} into Integer"
        end
        idx_raw = k.to_int
        raise TypeError, "can't convert #{k.class} into Integer" unless idx_raw.is_a?(Integer)
        idx = idx_raw < 0 ? mems.size + idx_raw : idx_raw
        return h unless idx >= 0 && idx < mems.size
        h[k] = @struct_values&.fetch(mems[idx], nil)
      end
    end
    h
  end

  def [](name_or_idx)
    mems = members
    if name_or_idx.is_a?(Integer)
      idx = name_or_idx < 0 ? mems.size + name_or_idx : name_or_idx
      raise IndexError, "offset #{name_or_idx} too small for struct(size:#{mems.size})" if idx < 0
      raise IndexError, "offset #{name_or_idx} too large for struct(size:#{mems.size})" if idx >= mems.size
      @struct_values&.fetch(mems[idx], nil)
    elsif name_or_idx.is_a?(Symbol) || name_or_idx.is_a?(String)
      name = name_or_idx.to_sym
      raise NameError, "no member '#{name_or_idx}' in struct" unless mems.include?(name)
      @struct_values&.fetch(name, nil)
    else
      raise TypeError, "no implicit conversion of #{name_or_idx.class} into Integer"
    end
  end

  def []=(name_or_idx, val)
    raise FrozenError, "can't modify frozen #{self.class}" if frozen?
    mems = members
    if name_or_idx.is_a?(Integer)
      idx = name_or_idx < 0 ? mems.size + name_or_idx : name_or_idx
      raise IndexError, "offset #{name_or_idx} too small for struct(size:#{mems.size})" if idx < 0
      raise IndexError, "offset #{name_or_idx} too large for struct(size:#{mems.size})" if idx >= mems.size
      (@struct_values ||= {})[mems[idx]] = val
    elsif name_or_idx.is_a?(Symbol) || name_or_idx.is_a?(String)
      name = name_or_idx.to_sym
      raise NameError, "no member '#{name_or_idx}' in struct" unless mems.include?(name)
      (@struct_values ||= {})[name] = val
    else
      raise TypeError, "no implicit conversion of #{name_or_idx.class} into Integer"
    end
    val
  end

  def each(&block)
    return to_enum(:each) { size } unless block
    to_a.each(&block)
    self
  end

  def each_pair(&block)
    return to_enum(:each_pair) { size } unless block
    members.each { |m| block.call([m, @struct_values&.fetch(m, nil)]) }
    self
  end

  def values_at(*indices)
    mems = members
    result = []
    indices.each do |idx|
      if idx.is_a?(Range)
        b = idx.begin
        e = idx.end
        # Clamp beginless start to 0
        start = b.nil? ? 0 : b
        # Clamp endless end to struct size - 1 (fill no nils for endless)
        stop = e.nil? ? mems.size - 1 : (idx.exclude_end? ? e - 1 : e)
        (start..stop).each do |i|
          j = i < 0 ? mems.size + i : i
          raise RangeError, "#{idx} out of range" if j < 0
          result << (j < mems.size ? @struct_values&.fetch(mems[j], nil) : nil)
        end
      elsif idx.is_a?(Integer)
        result << self[idx]
      else
        raise TypeError, "no implicit conversion of #{idx.class} into Integer"
      end
    end
    result
  end

  def dig(key, *rest)
    val = begin
      self[key]
    rescue NameError, TypeError
      return nil
    end
    return val if rest.empty? || val.nil?
    raise TypeError, "#{val.class} does not have #dig method" unless val.respond_to?(:dig)
    val.dig(*rest)
  end

  def ==(other)
    return true if equal?(other)
    return false unless other.is_a?(self.class)
    pair = __id__ < other.__id__ ? [__id__, other.__id__] : [other.__id__, __id__]
    seen = (Fiber[:_struct_eq_seen] ||= [])
    return true if seen.include?(pair)
    seen << pair
    begin
      members.all? { |m| (@struct_values&.fetch(m, nil)) == other[m] }
    ensure
      seen.pop
    end
  end

  def eql?(other)
    return true if equal?(other)
    return false unless other.is_a?(self.class)
    pair = __id__ < other.__id__ ? [__id__, other.__id__] : [other.__id__, __id__]
    seen = (Fiber[:_struct_eql_seen] ||= [])
    return true if seen.include?(pair)
    seen << pair
    begin
      members.all? { |m| (@struct_values&.fetch(m, nil)).eql?(other[m]) }
    ensure
      seen.pop
    end
  end

  def hash
    seen = (Fiber[:_struct_hash_seen] ||= [])
    # Recursive detection: when this struct is encountered again while being hashed,
    # throw non-locally so the contribution at the OUTERMOST level becomes 0.
    throw Fiber[:_struct_hash_tag] if seen.include?(__id__) && !Fiber[:_struct_hash_tag].nil?

    seen << __id__
    is_outer = Fiber[:_struct_hash_tag].nil?
    tag = is_outer ? (Fiber[:_struct_hash_tag] = Object.new) : Fiber[:_struct_hash_tag]
    begin
      values = if is_outer
        # Outer: catch each member's hash (recursive members throw here → 0)
        to_a.map { |m| catch(tag) { m.hash } || 0 }
      else
        # Inner: no catch — recursive throws propagate to the outermost catch
        to_a.map { |m| m.hash }
      end
      [self.class, values].hash
    ensure
      seen.pop
      Fiber[:_struct_hash_tag] = nil if is_outer
    end
  end

  def inspect
    # Use intrinsic name to bypass any user-overridden #name method.
    # Treat as anonymous if the name contains anonymous namespace components.
    raw_name = Intrinsics.module_name(self.class)
    name = raw_name && !raw_name.include?("#<") ? raw_name : nil
    pairs = members.map { |m| "#{m}=#{(@struct_values&.fetch(m, nil)).inspect}" }.join(', ')
    name ? "#<struct #{name} #{pairs}>" : "#<struct #{pairs}>"
  end
  alias to_s inspect

  def freeze
    @struct_values&.each_value(&:freeze) rescue nil
    super
  end

  def respond_to_missing?(name, include_private = false) = members.include?(name) || members.include?(name.to_s.sub(/=$/, '').to_sym)
end
