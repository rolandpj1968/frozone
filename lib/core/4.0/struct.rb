class Struct
  include Enumerable

  def self.new(*members, keyword_init: nil, &block)
    keyword_init_val = keyword_init

    klass = Class.new(self) do
      @members        = members.map(&:to_sym)
      @keyword_init   = keyword_init_val

      # Generate reader/writer for each member
      @members.each do |name|
        define_method(name)       { @struct_values[name] }
        define_method(:"#{name}=") { |v| @struct_values[name] = v }
      end

      def self.members        = @members
      def self.keyword_init?  = @keyword_init

      def initialize(*args, **kwargs)
        mems = self.class.members
        @struct_values = {}
        if self.class.keyword_init?
          raise ArgumentError, "wrong number of arguments (given #{args.size}, expected 0)" unless args.empty?
          unknown = kwargs.keys - mems
          raise ArgumentError, "unknown keywords: #{unknown.map(&:inspect).join(', ')}" unless unknown.empty?
          mems.each { |m| @struct_values[m] = kwargs[m] }
        else
          raise ArgumentError, "struct size differs" if args.size > mems.size
          mems.each_with_index { |m, i| @struct_values[m] = args[i] }
        end
      end

      class_eval(&block) if block
    end

    klass
  end

  def self.members = []

  def members    = self.class.members
  def to_a       = members.map { |m| @struct_values[m] }
  alias deconstruct to_a
  def values     = to_a
  def size       = members.size
  alias length size

  def to_h(&block)
    h = {}
    members.each { |m| h[m] = @struct_values[m] }
    block ? h.map(&block).to_h : h
  end

  def deconstruct_keys(keys)
    return to_h if keys.nil?
    h = {}
    keys.each { |k| h[k] = @struct_values[k] if members.include?(k) }
    h
  end

  def [](name_or_idx)
    if name_or_idx.is_a?(Integer)
      idx = name_or_idx < 0 ? members.size + name_or_idx : name_or_idx
      raise IndexError, "offset #{name_or_idx} too small for struct(size:#{members.size})" if idx < 0
      raise IndexError, "offset #{name_or_idx} too large for struct(size:#{members.size})" if idx >= members.size
      @struct_values[members[idx]]
    else
      name = name_or_idx.to_sym
      raise NameError, "no member '#{name_or_idx}' in struct" unless members.include?(name)
      @struct_values[name]
    end
  end

  def []=(name_or_idx, val)
    if name_or_idx.is_a?(Integer)
      idx = name_or_idx < 0 ? members.size + name_or_idx : name_or_idx
      raise IndexError, "offset #{name_or_idx} too small for struct(size:#{members.size})" if idx < 0
      raise IndexError, "offset #{name_or_idx} too large for struct(size:#{members.size})" if idx >= members.size
      @struct_values[members[idx]] = val
    else
      name = name_or_idx.to_sym
      raise NameError, "no member '#{name_or_idx}' in struct" unless members.include?(name)
      @struct_values[name] = val
    end
    val
  end

  def each(&block)
    return to_enum(:each) unless block
    to_a.each(&block)
    self
  end

  def each_pair(&block)
    return to_enum(:each_pair) unless block
    members.each { |m| block.call(m, @struct_values[m]) }
    self
  end

  def values_at(*indices)
    indices.map { |i| self[i] }
  end

  def ==(other)
    return false unless other.is_a?(self.class)
    members.all? { |m| @struct_values[m] == other[m] }
  end

  def eql?(other)
    return false unless other.is_a?(self.class)
    members.all? { |m| @struct_values[m].eql?(other[m]) }
  end

  def hash
    [self.class, to_a].hash
  end

  def inspect
    name = self.class.name
    pairs = members.map { |m| "#{m}=#{@struct_values[m].inspect}" }.join(', ')
    name ? "#<struct #{name} #{pairs}>" : "#<struct #{pairs}>"
  end

  alias to_s inspect

  def freeze
    @struct_values.each_value(&:freeze) rescue nil
    super
  end

  def respond_to_missing?(name, include_private = false)
    members.include?(name) || members.include?(name.to_s.sub(/=$/, '').to_sym)
  end
end
