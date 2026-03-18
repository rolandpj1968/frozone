class Data
  include Comparable

  def self.define(*members, &block)
    syms = members.map do |m|
      case m
      when Symbol then m
      when String then m.to_sym
      else raise TypeError, "#{m.inspect} is not a Symbol"
      end
    end

    seen = {}
    syms.each do |s|
      raise ArgumentError, "duplicate member: #{s}" if seen[s]
      seen[s] = true
    end

    klass = Class.new(self) do
      @data_members = syms

      syms.each do |name|
        define_method(name) { @data_values[name] }
      end

      def self.members = @data_members || superclass.members

      def self.new(*args, **kwargs, &blk)
        obj = allocate
        mems = members
        if !args.empty? && kwargs.empty? && args.size == mems.size
          kwargs = mems.zip(args).to_h
          args = []
        end
        obj.__send__(:initialize, *args, **kwargs)
        obj.freeze
        obj
      end

      def self.[](*args, **kwargs) = new(*args, **kwargs)
    end

    klass.class_eval(&block) if block
    klass
  end

  def self.members = @data_members || []

  def self.[](*args, **kwargs) = new(*args, **kwargs)

  def initialize(*args, **kwargs)
    mems = self.class.members
    @data_values = {}

    # Handle hash with all-string keys passed as a positional argument
    if args.size == 1 && args.first.is_a?(Hash) && kwargs.empty? &&
       args.first.keys.all? { |k| k.is_a?(String) }
      kwargs = args.first.transform_keys { |k| k.to_sym }
      args = []
    end

    # Normalize string keys in kwargs to symbol keys (Frozone may pass string-keyed hashes as kwargs)
    if kwargs.keys.any? { |k| k.is_a?(String) }
      kwargs = kwargs.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
    end

    if args.empty?
      # keyword form
      unknown = kwargs.keys - mems
      if unknown.size == 1
        raise ArgumentError, "unknown keyword: :#{unknown.first}"
      elsif !unknown.empty?
        raise ArgumentError, "unknown keywords: #{unknown.map { |k| ":#{k}" }.join(', ')}"
      end
      missing = mems - kwargs.keys
      if missing.size == 1
        raise ArgumentError, "missing keyword: :#{missing.first}"
      elsif !missing.empty?
        raise ArgumentError, "missing keywords: #{missing.map { |k| ":#{k}" }.join(', ')}"
      end
      mems.each { |m| @data_values[m] = kwargs[m] }
    elsif kwargs.empty?
      # positional form
      if args.size != mems.size
        raise ArgumentError, "wrong number of arguments (given #{args.size}, expected #{mems.size})"
      end
      mems.each_with_index { |m, i| @data_values[m] = args[i] }
    else
      raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)"
    end
  end

  def members = self.class.members

  def to_h(&block)
    if block
      h = {}
      self.class.members.each do |m|
        pair = block.call(m, @data_values[m])
        unless pair.is_a?(Array)
          if pair.respond_to?(:to_ary)
            pair = pair.to_ary
            raise TypeError, "wrong element type #{pair.class} (expected Array)" unless pair.is_a?(Array)
          else
            raise TypeError, "wrong element type #{pair.class} (expected Array)"
          end
        end
        raise ArgumentError, "element has wrong array length (expected 2, was #{pair.length})" unless pair.length == 2
        h[pair[0]] = pair[1]
      end
      h
    else
      h = {}
      self.class.members.each { |m| h[m] = @data_values[m] }
      h
    end
  end

  def deconstruct = self.class.members.map { |m| @data_values[m] }

  def deconstruct_keys(keys)
    raise TypeError, "expected Array or nil" unless keys.nil? || keys.is_a?(Array)
    return to_h if keys.nil?

    mems = self.class.members
    return {} if keys.size > mems.size

    result = {}
    keys.each do |k|
      case k
      when Symbol
        break unless mems.include?(k)
        result[k] = @data_values[k]
      when String
        sym = k.to_sym
        break unless mems.include?(sym)
        result[k] = @data_values[sym]
      when Integer
        idx = k < 0 ? mems.length + k : k
        break if idx < 0 || idx >= mems.length
        result[k] = @data_values[mems[idx]]
      else
        if k.respond_to?(:to_int)
          int = k.to_int
          raise TypeError, "can't convert #{k.class} into Integer" unless int.is_a?(Integer)
          idx = int < 0 ? mems.length + int : int
          break if idx < 0 || idx >= mems.length
          result[k] = @data_values[mems[idx]]
        else
          raise TypeError, "no implicit conversion of #{k.class} into Integer"
        end
      end
    end
    result
  end

  EQ_GUARD = []

  def ==(other)
    return true if equal?(other)
    return false unless other.is_a?(self.class)
    pair = object_id <= other.object_id ? [object_id, other.object_id] : [other.object_id, object_id]
    return true if EQ_GUARD.include?(pair)
    EQ_GUARD << pair
    begin
      self.class.members.all? { |m| @data_values[m] == other.__send__(m) }
    ensure
      EQ_GUARD.delete(pair)
    end
  end

  def eql?(other)
    return false unless other.is_a?(self.class)
    self.class.members.all? { |m| @data_values[m].eql?(other.__send__(m)) }
  end

  def hash
    [self.class, *self.class.members.map { |m| @data_values[m] }].hash
  end

  def with(**kwargs)
    return self if kwargs.empty?
    kwargs = kwargs.transform_keys { |k| k.is_a?(String) ? k.to_sym : k }
    unknown = kwargs.keys - self.class.members
    raise ArgumentError, "unknown keywords: #{unknown.map(&:to_s).join(', ')}" unless unknown.empty?
    current = to_h
    self.class.allocate.tap do |obj|
      obj.__send__(:initialize, **current.merge(kwargs))
      obj.freeze
    end
  end

  INSPECT_GUARD = []

  def inspect
    raw_name = Intrinsics.module_name(self.class)
    klass_name = raw_name && !raw_name.include?("#<") && raw_name != 'Data' ? raw_name : nil

    oid = object_id
    if INSPECT_GUARD.include?(oid)
      return "#<data #{self.class.inspect}:...>"
    end

    INSPECT_GUARD << oid
    begin
      attrs = self.class.members.map { |m| "#{m}=#{@data_values[m].inspect}" }.join(', ')
      if klass_name
        attrs.empty? ? "#<data #{klass_name}>" : "#<data #{klass_name} #{attrs}>"
      else
        attrs.empty? ? '#<data>' : "#<data #{attrs}>"
      end
    ensure
      INSPECT_GUARD.delete(oid)
    end
  end

  alias to_s inspect
end
