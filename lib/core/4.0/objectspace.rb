module ObjectSpace
  def self.each_object(klass = nil, &block)
    return to_enum(:each_object, klass) unless block
    Intrinsics.objectspace_each_object(klass, block)
  end

  def self.define_finalizer(obj, proc_arg = nil, &block) = Intrinsics.objectspace_define_finalizer(obj, proc_arg, block)
  def self.undefine_finalizer(obj) = Intrinsics.objectspace_undefine_finalizer(obj)

  def self._id2ref(id)
    warn "warning: ObjectSpace._id2ref is deprecated and will be removed in future"
    Intrinsics.objectspace_id2ref(id)
  end

  def self.garbage_collect(**opts) = Intrinsics.objectspace_garbage_collect

  def self.count_objects(result = nil) = Intrinsics.objectspace_count_objects(result)

  # WeakMap: identity-keyed map (keys compared by object_id, not equality).
  # In a single-process interpreter without real GC pressure, we don't
  # implement actual weak references — entries persist until explicitly removed.
  class WeakMap
    include Enumerable

    def initialize
      # Store as array of [key, value] pairs; identity lookup via object_id
      @pairs = []
    end

    def []=(key, value)
      idx = @pairs.index { |k, _v| k.equal?(key) }
      if idx
        @pairs[idx][1] = value
      else
        @pairs << [key, value]
      end
      value
    end

    def [](key)
      pair = @pairs.find { |k, _v| k.equal?(key) }
      pair ? pair[1] : nil
    end

    def key?(key)
      @pairs.any? { |k, _v| k.equal?(key) }
    end

    alias include? key?
    alias member? key?

    def delete(key)
      idx = @pairs.index { |k, _v| k.equal?(key) }
      if idx
        @pairs.delete_at(idx)[1]
      elsif block_given?
        yield key
      else
        nil
      end
    end

    def each(&block)
      return self if @pairs.empty? && !block_given?
      raise LocalJumpError, "no block given" unless block_given?
      @pairs.each { |k, v| block.call(k, v) }
      self
    end

    alias each_pair each

    def each_key
      return self if @pairs.empty? && !block_given?
      raise LocalJumpError, "no block given" unless block_given?
      @pairs.each { |k, _v| yield k }
      self
    end

    def each_value
      return self if @pairs.empty? && !block_given?
      raise LocalJumpError, "no block given" unless block_given?
      @pairs.each { |_k, v| yield v }
      self
    end

    def keys
      @pairs.map { |k, _v| k }
    end

    def values
      @pairs.map { |_k, v| v }
    end

    def size
      @pairs.size
    end

    alias length size

    def inspect
      if @pairs.empty?
        "#<ObjectSpace::WeakMap:0x#{object_id.to_s(16)}>"
      else
        entries = @pairs.map do |k, v|
          k_str = _weakmap_inspect_obj(k)
          v_str = _weakmap_inspect_obj(v)
          "#{k_str} => #{v_str}"
        end.join(", ")
        "#<ObjectSpace::WeakMap:0x#{object_id.to_s(16)}: #{entries}>"
      end
    end

    private

    def _weakmap_inspect_obj(obj)
      obj.inspect
    rescue NoMethodError
      "#<BasicObject:0x#{obj.__id__.to_s(16)}>"
    end
  end

  # WeakKeyMap: equality-keyed map (keys compared via #hash and #eql?).
  # Primitive values (Integer, Float, Symbol, true, false, nil) cannot be keys.
  # In this interpreter, no actual weak references; entries persist until removed.
  class WeakKeyMap
    def initialize
      # Store as array of [key, value] pairs; equality lookup via hash/eql?
      @pairs = []
    end

    def []=(key, value)
      __check_key__!(key)
      idx = __find_index__(key)
      if idx
        @pairs[idx][1] = value
      else
        @pairs << [key, value]
      end
      value
    end

    def [](key)
      return nil if __ungcable__?(key)
      pair = __find_pair__(key)
      pair ? pair[1] : nil
    end

    def key?(key)
      return false if __ungcable__?(key)
      !__find_pair__(key).nil?
    end

    def delete(key)
      return nil if __ungcable__?(key)
      idx = __find_index__(key)
      if idx
        @pairs.delete_at(idx)[1]
      elsif block_given?
        yield key
      else
        nil
      end
    end

    def getkey(key)
      return nil if __ungcable__?(key)
      pair = __find_pair__(key)
      pair ? pair[0] : nil
    end

    def clear
      @pairs.clear
      self
    end

    def inspect
      "#<ObjectSpace::WeakKeyMap:0x#{object_id.to_s(16)} size=#{@pairs.size}>"
    end

    private

    def __ungcable__?(key)
      # Check for nil/true/false using identity (works even for BasicObject)
      return true if key.equal?(nil) || key.equal?(true) || key.equal?(false)
      begin
        key.is_a?(Integer) || key.is_a?(Float) || key.is_a?(Symbol)
      rescue NoMethodError
        # BasicObject doesn't have is_a? - not ungcable
        false
      end
    end

    def __find_pair__(key)
      # Use send(:hash) to allow private #hash
      key_hash = key.__send__(:hash)
      @pairs.find do |k, _v|
        k.equal?(key) || (k.__send__(:hash) == key_hash && key.__send__(:eql?, k))
      end
    rescue NoMethodError
      nil
    end

    def __find_index__(key)
      key_hash = key.__send__(:hash)
      @pairs.index do |k, _v|
        k.equal?(key) || (k.__send__(:hash) == key_hash && key.__send__(:eql?, k))
      end
    end

    def __check_key__!(key)
      # Check for ungcable primitive types using identity first (BasicObject-safe)
      if key.equal?(nil) || key.equal?(true) || key.equal?(false)
        raise ArgumentError, "WeakKeyMap keys must be garbage collectable"
      end
      begin
        if key.is_a?(Integer) || key.is_a?(Float) || key.is_a?(Symbol)
          raise ArgumentError, "WeakKeyMap keys must be garbage collectable"
        end
      rescue NoMethodError
        # BasicObject doesn't have is_a? - ok to use as key
      end
      begin
        # Use send to allow calling private #hash
        key.__send__(:hash)
      rescue NoMethodError
        klass_name = begin
          Intrinsics.object_class(key).name
        rescue
          "BasicObject"
        end
        raise NoMethodError, "undefined method 'hash' for an instance of #{klass_name}"
      end
      nil
    end
  end
end
