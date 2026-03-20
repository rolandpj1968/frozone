# encoding: binary

# Marshal - Ruby object serialization/deserialization
# Implements the Marshal binary format (version 4.8)

module Marshal
  MAJOR_VERSION = 4
  MINOR_VERSION = 8

  extend self # rubocop:disable Style/ModuleFunction

  # Type codes
  TYPE_NIL      = '0'
  TYPE_TRUE     = 'T'
  TYPE_FALSE    = 'F'
  TYPE_INTEGER  = 'i'
  TYPE_BIGNUM   = 'l'
  TYPE_FLOAT    = 'f'
  TYPE_STRING   = '"'
  TYPE_SYMBOL   = ':'
  TYPE_SYMLINK  = ';'
  TYPE_ARRAY    = '['
  TYPE_HASH     = '{'
  TYPE_HASH_DEF = '}'
  TYPE_OBJECT   = 'o'
  TYPE_STRUCT   = 'S'
  TYPE_CLASS    = 'c'
  TYPE_MODULE   = 'm'
  TYPE_IVAR     = 'I'
  TYPE_LINK     = '@'
  TYPE_UCLASS   = 'C'
  TYPE_USERDEFINED = 'u'
  TYPE_USERMARSH   = 'U'
  TYPE_EXTENDED    = 'e'
  TYPE_REGEXP   = '/'
  TYPE_DATA     = 'd'

  # ─── Dumper ────────────────────────────────────────────────────────────────

  class Dumper
    def initialize(limit)
      @limit   = limit   # recursion depth limit (-1 = unlimited)
      @depth   = 0       # current recursion depth
      @symbols = {}      # symbol → index
      @objects = {}      # object_id → index; index 0 = first object after symbols
      @out     = ''.b
    end

    def dump(obj)
      @out << "\x04\x08"
      write_object(obj)
      @out
    end

    private

    def write_object(obj)
      if @limit >= 0
        raise ArgumentError, "exceed depth limit" if @depth >= @limit
        @depth += 1
        result = write_object_inner(obj)
        @depth -= 1
        result
      else
        write_object_inner(obj)
      end
    end

    def write_object_inner(obj)
      # Nil / true / false — not tracked in object table
      # Use .equal?(nil) to support BasicObject subclasses that don't define nil?
      if obj.equal?(nil)
        @out << TYPE_NIL
        return
      end
      if obj.equal?(true)
        @out << TYPE_TRUE
        return
      end
      if obj.equal?(false)
        @out << TYPE_FALSE
        return
      end

      # Integer (fixnum) — not tracked
      if obj.is_a?(Integer) && !(obj > 0x3fffffff || obj < -0x40000000)
        write_integer(obj)
        return
      end

      # Symbol — use symbol link table, not object table
      if obj.is_a?(Symbol)
        write_symbol(obj)
        return
      end

      # For all other objects, check the object link table first
      oid = obj.object_id
      if @objects.key?(oid)
        write_link(@objects[oid])
        return
      end

      # Before writing, we may need to wrap with TYPE_IVAR or TYPE_EXTENDED
      # Dispatch to the right serializer based on class
      if obj.is_a?(Float)
        track(obj)
        write_float(obj)
      elsif obj.is_a?(Integer) && (obj > 0x3fffffff || obj < -0x40000000)
        track(obj)
        write_bignum(obj)
      elsif obj.is_a?(String)
        write_string_with_ivar(obj)
      elsif obj.is_a?(Symbol)
        # handled above, but just in case
        write_symbol(obj)
      elsif obj.is_a?(IO) || obj.is_a?(File)
        raise TypeError, "no _dump_data is defined for class #{obj.class}"
      elsif obj.is_a?(MatchData)
        raise TypeError, "no _dump_data is defined for class #{obj.class}"
      elsif obj.is_a?(Method) || obj.is_a?(UnboundMethod) || obj.is_a?(Proc)
        raise TypeError, "no _dump_data is defined for class #{obj.class}"
      elsif defined?(Mutex) && obj.is_a?(Mutex)
        raise TypeError, "no _dump_data is defined for class #{obj.class}"
      elsif obj.is_a?(Array)
        write_array_with_wraps(obj)
      elsif obj.is_a?(Hash)
        write_hash_with_wraps(obj)
      elsif obj.is_a?(Regexp)
        write_regexp_with_ivar(obj)
      elsif obj.is_a?(Class)
        track(obj)
        write_class(obj)
      elsif obj.is_a?(Module)
        track(obj)
        write_module(obj)
      elsif obj.is_a?(Exception)
        write_exception(obj)
      elsif obj.is_a?(Struct)
        write_struct_with_wraps(obj)
      elsif defined?(Data) && obj.is_a?(Data)
        write_data_as_struct(obj)
      elsif respond_to_marshal_dump?(obj)
        write_user_marshal(obj)
      elsif respond_to__dump?(obj)
        write_user_defined(obj)
      elsif obj.is_a?(Range)
        write_range(obj)
      else
        write_generic_object(obj)
      end
    end

    def respond_to_marshal_dump?(obj)
      obj.respond_to?(:marshal_dump, true)
    end

    def respond_to__dump?(obj)
      obj.respond_to?(:_dump, true)
    end

    def track(obj)
      @objects[obj.object_id] = @objects.size
    end

    def write_link(index)
      @out << TYPE_LINK
      write_long(index)
    end
    # ── Integers ──────────────────────────────────────────────────────────────

    def write_integer(n)
      @out << TYPE_INTEGER
      write_long(n)
    end

    def write_long(n)
      if n == 0
        @out << "\x00"
        return
      end
      if n > 0
        if n < 123
          @out << (n + 5).chr
          return
        end
        if n < 0x100
          @out << "\x01" << n.chr
          return
        end
        if n < 0x10000
          @out << "\x02" << (n & 0xff).chr << ((n >> 8) & 0xff).chr
          return
        end
        if n < 0x1000000
          @out << "\x03" << (n & 0xff).chr << ((n >> 8) & 0xff).chr << ((n >> 16) & 0xff).chr
          return
        end
        @out << "\x04" << (n & 0xff).chr << ((n >> 8) & 0xff).chr << ((n >> 16) & 0xff).chr << ((n >> 24) & 0xff).chr
      else
        if n >= -123
          @out << (256 + n - 5).chr
          return
        end
        if n >= -0x100
          @out << "\xff" << (256 + n).chr
          return
        end
        if n >= -0x10000
          @out << "\xfe" << (n & 0xff).chr << ((n >> 8) & 0xff).chr
          return
        end
        if n >= -0x1000000
          @out << "\xfd" << (n & 0xff).chr << ((n >> 8) & 0xff).chr << ((n >> 16) & 0xff).chr
          return
        end
        @out << "\xfc" << (n & 0xff).chr << ((n >> 8) & 0xff).chr << ((n >> 16) & 0xff).chr << ((n >> 24) & 0xff).chr
      end
    end
    # ── Bignum ────────────────────────────────────────────────────────────────

    def write_bignum(n)
      @out << TYPE_BIGNUM
      if n >= 0
        @out << '+'
        bytes = bignum_to_bytes(n)
      else
        @out << '-'
        bytes = bignum_to_bytes(-n)
      end
      num_shorts = (bytes.size + 1) / 2
      write_long(num_shorts)
      @out << bytes
      @out << "\x00" if bytes.size.odd?
    end

    def bignum_to_bytes(n)
      bytes = ''.b
      while n > 0
        bytes << (n & 0xff).chr
        n >>= 8
      end
      bytes
    end
    # ── Float ─────────────────────────────────────────────────────────────────

    def write_float(f)
      @out << TYPE_FLOAT
      s = float_to_string(f)
      write_long(s.bytesize)
      @out << s
    end

    def float_to_string(f)
      if f.nan?
        'nan'
      elsif f.infinite? == 1
        'inf'
      elsif f.infinite? == -1
        '-inf'
      else
        # MRI Marshal uses Ruby's to_s format but with adjustments:
        # 1. Remove trailing ".0" (1.0 → "1", 0.0 → "0")
        # 2. Normalize exponent: e-09 → e-9, e+09 → e+9
        s = f.to_s
        # Remove trailing .0 for integer-valued floats (not in scientific notation)
        s = s.sub(/\.0$/, '') unless s.include?('e') || s.include?('E')
        # Normalize exponent: remove leading zeros in exponent
        s.sub(/e([+-])0+(\d)/, 'e\1\2')

      end
    end
    # ── Symbol ────────────────────────────────────────────────────────────────

    def write_symbol(sym)
      str = sym.to_s
      if @symbols.key?(str)
        @out << TYPE_SYMLINK
        write_long(@symbols[str])
      else
        @symbols[str] = @symbols.size
        enc_ivar = begin; encoding_ivar(str.encoding); rescue; nil; end
        if enc_ivar
          @out << TYPE_IVAR
        end
        @out << TYPE_SYMBOL
        write_long(str.bytesize)
        @out << str.b
        if enc_ivar
          write_long(1)
          write_enc_ivar(enc_ivar)
        end
      end
    end

    def write_symbol_str(str)
      if @symbols.key?(str)
        @out << TYPE_SYMLINK
        write_long(@symbols[str])
      else
        @symbols[str] = @symbols.size
        @out << TYPE_SYMBOL
        write_long(str.bytesize)
        @out << str.b
      end
    end
    # ── String ────────────────────────────────────────────────────────────────

    def write_string_with_ivar(obj)
      # Determine modules and ivars
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)

      # Figure out encoding ivar
      enc = obj.encoding
      enc_ivar = encoding_ivar(enc)

      subclass = (obj.class != String)
      n_ivars = ivars.size / 2 + (enc_ivar ? 1 : 0)
      needs_ivar = n_ivars > 0

      # TYPE_IVAR must come before TYPE_EXTENDED/TYPE_UCLASS wrappers (MRI ordering)
      @out << TYPE_IVAR if needs_ivar
      mods.each { |m| write_extension_prefix(m) }
      write_uclass(obj.class) if subclass

      # Track object (object table entry for the string itself)
      track(obj)

      write_raw_string(obj)

      # Write ivars after
      if needs_ivar
        write_long(n_ivars)
        write_enc_ivar(enc_ivar) if enc_ivar
        i = 0
        while i < ivars.size
          write_symbol(ivars[i])
          write_object(ivars[i + 1])
          i += 2
        end
      end
    end

    def write_raw_string(obj)
      raw = obj.b rescue obj
      bytes = raw.is_a?(String) ? raw : obj.to_s.b
      @out << TYPE_STRING
      write_long(bytes.bytesize)
      @out << bytes
    end

    def encoding_ivar(enc)
      name = enc.name
      if name == 'UTF-8'
        [:E, true]
      elsif name == 'US-ASCII' || name == 'ASCII'
        [:E, false]
      elsif name == 'ASCII-8BIT' || name == 'BINARY'
        nil  # binary strings don't need encoding ivar
      else
        [:encoding, name]
      end
    end

    # Write an encoding ivar key+value pair.
    # The value is written as a raw binary string (no IVAR wrapper) — MRI behavior.
    def write_enc_ivar(enc_ivar)
      key, val = enc_ivar
      write_symbol(key)
      if val.equal?(true) || val.equal?(false)
        @out << (val ? TYPE_TRUE : TYPE_FALSE)
      else
        # Encoding name: write as plain binary string without IVAR wrapping
        bytes = val.b rescue val.to_s.b
        @out << TYPE_STRING
        write_long(bytes.bytesize)
        @out << bytes
      end
    end

    def collect_ivars(obj)
      result = []
      obj.instance_variables.each do |iv|
        result << iv
        result << obj.instance_variable_get(iv)
      end
      result
    end

    def extended_modules(obj)
      can_singleton = (obj.respond_to?(:singleton_class, true) rescue false)
      return [] unless can_singleton
      begin
        sc = obj.singleton_class
        # Get included modules on the singleton class up to (not including) the class itself
        mods = sc.included_modules
        klass_mods = obj.class.ancestors.select { |a| a.is_a?(Module) && !a.is_a?(Class) }
        mods - klass_mods
      rescue
        []
      end
    end

    def write_extension_prefix(mod)
      @out << TYPE_EXTENDED
      write_symbol_str(real_module_name(mod))
    end

    def write_uclass(klass)
      @out << TYPE_UCLASS
      write_symbol_str(real_class_name(klass))
    end
    # ── Array ─────────────────────────────────────────────────────────────────

    def write_array_with_wraps(obj)
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)
      subclass = (obj.class != Array)
      needs_ivar = !ivars.empty?

      mods.each { |m| write_extension_prefix(m) }
      write_uclass(obj.class) if subclass
      @out << TYPE_IVAR if needs_ivar

      track(obj)
      write_raw_array(obj)

      if needs_ivar
        write_long(ivars.size / 2)
        i = 0
        while i < ivars.size
          write_symbol(ivars[i])
          write_object(ivars[i + 1])
          i += 2
        end
      end
    end

    def write_raw_array(obj)
      @out << TYPE_ARRAY
      write_long(obj.size)
      obj.each { |e| write_object(e) }
    end
    # ── Hash ──────────────────────────────────────────────────────────────────

    def write_hash_with_wraps(obj)
      if obj.default_proc
        raise TypeError, "can't dump hash with default proc"
      end
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)
      subclass = (obj.class != Hash)
      compare_by_id = obj.compare_by_identity?
      needs_ivar = !ivars.empty?

      # TYPE_IVAR must come before TYPE_EXTENDED/TYPE_UCLASS wrappers (MRI ordering)
      @out << TYPE_IVAR if needs_ivar
      mods.each { |m| write_extension_prefix(m) }

      if compare_by_id && subclass
        # compare_by_identity Hash subclass: wrap with C:Hash then C:SubClass
        write_uclass(obj.class)
        write_uclass(Hash)
      elsif compare_by_id
        write_uclass(Hash)
      elsif subclass
        write_uclass(obj.class)
      end

      track(obj)
      write_raw_hash(obj)

      if needs_ivar
        write_long(ivars.size / 2)
        i = 0
        while i < ivars.size
          write_symbol(ivars[i])
          write_object(ivars[i + 1])
          i += 2
        end
      end
    end

    def write_raw_hash(obj)
      has_default = !obj.default.nil? && !obj.default_proc
      @out << (has_default ? TYPE_HASH_DEF : TYPE_HASH)
      write_long(obj.size)
      obj.each_pair { |k, v| write_object(k); write_object(v) }
      write_object(obj.default) if has_default
    end
    # ── Regexp ────────────────────────────────────────────────────────────────

    def write_regexp_with_ivar(obj)
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)
      subclass = !(obj.instance_of?(Regexp))

      enc = obj.source.encoding
      enc_ivar = encoding_ivar(enc)

      n_ivars = ivars.size / 2 + (enc_ivar ? 1 : 0)
      needs_ivar = n_ivars > 0

      # TYPE_IVAR must come before TYPE_EXTENDED/TYPE_UCLASS wrappers (MRI ordering)
      @out << TYPE_IVAR if needs_ivar
      mods.each { |m| write_extension_prefix(m) }
      write_uclass(obj.class) if subclass

      track(obj)
      write_raw_regexp(obj)

      if needs_ivar
        write_long(n_ivars)
        write_enc_ivar(enc_ivar) if enc_ivar
        i = 0
        while i < ivars.size
          write_symbol(ivars[i])
          write_object(ivars[i + 1])
          i += 2
        end
      end
    end

    def write_raw_regexp(obj)
      @out << TYPE_REGEXP
      src = obj.source.b rescue obj.source
      write_long(src.bytesize)
      @out << src
      @out << (obj.options & 0x7f).chr
    end
    # ── Class / Module ────────────────────────────────────────────────────────

    def write_class(klass)
      check_anonymous(klass)
      name = real_class_name(klass)
      needs_ivar = name.bytes.any? { |b| b > 127 }
      @out << TYPE_IVAR if needs_ivar
      @out << TYPE_CLASS
      write_long(name.bytesize)
      @out << name.b
      if needs_ivar
        write_long(1)
        write_enc_ivar([:E, true])
      end
    end

    def write_module(mod)
      check_anonymous(mod)
      name = real_module_name(mod)
      needs_ivar = name.bytes.any? { |b| b > 127 }
      @out << TYPE_IVAR if needs_ivar
      @out << TYPE_MODULE
      write_long(name.bytesize)
      @out << name.b
      if needs_ivar
        write_long(1)
        write_enc_ivar([:E, true])
      end
    end

    def write_class_name(klass)
      check_anonymous(klass)
      name = real_class_name(klass)
      write_long(name.bytesize)
      @out << name.b
    end

    def write_module_name(mod)
      check_anonymous(mod)
      name = real_module_name(mod)
      write_long(name.bytesize)
      @out << name.b
    end

    def real_class_name(klass)
      # Use Module.instance_method(:name) to bypass overridden .name
      Module.instance_method(:name).bind(klass).call.to_s
    end

    def real_module_name(mod)
      Module.instance_method(:name).bind(mod).call.to_s
    end

    def check_anonymous(mod)
      name = begin
        real_class_name(mod)
      rescue
        begin
          real_module_name(mod)
        rescue
          nil
        end
      end
      if name.nil? || name.empty?
        kind = mod.is_a?(Class) ? 'class' : 'module'
        raise TypeError, "can't dump anonymous #{kind} #{mod.inspect}"
      end
    end
    # ── Struct ────────────────────────────────────────────────────────────────

    def write_struct_with_wraps(obj)
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)
      needs_ivar = !ivars.empty?

      mods.each { |m| write_extension_prefix(m) }
      @out << TYPE_IVAR if needs_ivar

      track(obj)
      write_raw_struct(obj)

      if needs_ivar
        write_long(ivars.size / 2)
        i = 0
        while i < ivars.size
          write_symbol(ivars[i])
          write_object(ivars[i + 1])
          i += 2
        end
      end
    end

    def write_raw_struct(obj)
      klass = obj.class
      check_anonymous(klass)
      @out << TYPE_STRUCT
      write_symbol_str(real_class_name(klass))
      members = obj.members
      write_long(members.size)
      members.each do |m|
        write_symbol(m)
        write_object(obj[m])
      end
    end

    def write_data_as_struct(obj)
      klass = obj.class
      check_anonymous(klass)
      mods = extended_modules(obj)
      mods.each { |m| write_extension_prefix(m) }
      track(obj)
      @out << TYPE_STRUCT
      write_symbol_str(real_class_name(klass))
      members = obj.members
      write_long(members.size)
      members.each do |m|
        write_symbol(m)
        write_object(obj.send(m))
      end
    end
    # ── User-defined (_dump/_load) ────────────────────────────────────────────

    def write_user_defined(obj)
      mods = extended_modules(obj)

      klass = obj.class
      check_anonymous(klass)

      data = obj.__send__(:_dump, @depth)
      raise TypeError, "_dump must return a String, got #{data.class}" unless data.is_a?(String)

      # Collect ivars from the string returned by _dump (not from the object itself)
      # This includes the string's encoding ivar and any string instance variables
      str_ivars = collect_ivars(data)
      enc_ivar = encoding_ivar(data.encoding)

      n_ivars = str_ivars.size / 2 + (enc_ivar ? 1 : 0)
      needs_ivar = n_ivars > 0

      # TYPE_IVAR must come before TYPE_EXTENDED wrappers (MRI ordering)
      @out << TYPE_IVAR if needs_ivar
      mods.each { |m| write_extension_prefix(m) }

      track(obj)

      @out << TYPE_USERDEFINED
      write_symbol_str(real_class_name(klass))
      write_long(data.b.bytesize)
      @out << data.b

      if needs_ivar
        write_long(n_ivars)
        write_enc_ivar(enc_ivar) if enc_ivar
        i = 0
        while i < str_ivars.size
          write_symbol(str_ivars[i])
          write_object(str_ivars[i + 1])
          i += 2
        end
      end
    end
    # ── User-marshal (marshal_dump/marshal_load) ───────────────────────────────

    def write_user_marshal(obj)
      mods = extended_modules(obj)

      klass = obj.class
      check_anonymous(klass)

      mods.each { |m| write_extension_prefix(m) }

      track(obj)

      @out << TYPE_USERMARSH
      write_symbol_str(real_class_name(klass))
      data = obj.__send__(:marshal_dump)
      write_object(data)
    end
    # ── Exception ─────────────────────────────────────────────────────────────

    EXCEPTION_SKIP_IVARS = %i[@mesg @message @bt @backtrace @_has_locations @backtrace_locations].freeze

    def write_exception(obj)
      klass = obj.class
      check_anonymous(klass)
      mods = extended_modules(obj)

      # MRI marshal uses :mesg and :bt synthetic ivars; collect other ivars as pairs
      # Filter out the exception-internal ivars that become synthetic keys
      extra_pairs = []
      obj.instance_variables.each do |iv|
        next if EXCEPTION_SKIP_IVARS.include?(iv)

        extra_pairs << iv << obj.instance_variable_get(iv)
      end

      mods.each { |m| write_extension_prefix(m) }

      track(obj)

      # mesg = the exception message (nil if default)
      mesg = begin
        msg = obj.message
        msg == klass.to_s ? nil : msg
      rescue
        nil
      end

      # bt = backtrace (nil if none)
      bt = begin
        obj.backtrace
      rescue
        nil
      end

      all_ivars = [:mesg, mesg, :bt, bt]
      all_ivars += extra_pairs

      @out << TYPE_OBJECT
      write_symbol_str(real_class_name(klass))
      write_long(all_ivars.size / 2)
      i = 0
      while i < all_ivars.size
        write_symbol(all_ivars[i])
        write_object(all_ivars[i + 1])
        i += 2
      end
    end

    # ── Range ────────────────────────────────────────────────────────────────

    def write_range(obj)
      klass = obj.class
      is_subclass = (klass != Range)
      mods = extended_modules(obj)
      ivars = collect_ivars(obj)

      check_anonymous(klass) if is_subclass
      mods.each { |m| write_extension_prefix(m) }
      write_uclass(klass) if is_subclass

      track(obj)

      # Range stores begin, end, excl as synthetic ivars
      # Collected ivars from the range itself (if any)
      all_ivars = [:excl, obj.exclude_end?, :begin, obj.first, :end, obj.last] + ivars
      @out << TYPE_OBJECT
      write_symbol_str('Range')
      write_long(all_ivars.size / 2)
      i = 0
      while i < all_ivars.size
        write_symbol(all_ivars[i])
        write_object(all_ivars[i + 1])
        i += 2
      end
    end

    # ── Generic object ────────────────────────────────────────────────────────

    def write_generic_object(obj)
      klass = obj.class
      check_anonymous(klass)
      check_no_singleton(obj)

      mods = extended_modules(obj)
      mods.each do |m|
        name = begin; real_module_name(m); rescue; nil; end
        raise TypeError, "can't dump anonymous class #{obj.class}" if name.nil? || name.empty?
      end
      ivars = collect_ivars(obj)

      mods.each { |m| write_extension_prefix(m) }

      track(obj)

      @out << TYPE_OBJECT
      write_symbol_str(real_class_name(klass))
      write_long(ivars.size / 2)
      i = 0
      while i < ivars.size
        write_symbol(ivars[i])
        write_object(ivars[i + 1])
        i += 2
      end
    end

    def check_no_singleton(obj)
      can_singleton = (obj.respond_to?(:singleton_class, true) rescue false)
      return unless can_singleton
      begin
        sc = obj.singleton_class
        # Check for singleton methods
        if sc.respond_to?(:method_defined?) && sc.instance_methods(false).any?
          raise TypeError, "singleton can't be dumped"
        end
        # Check for singleton instance variables
        if sc.respond_to?(:instance_variables) && sc.instance_variables.any?
          raise TypeError, "singleton can't be dumped"
        end
      rescue TypeError
        raise
      rescue
        # ignore errors from singleton_class access
      end
    end
  end

  # ─── Loader ────────────────────────────────────────────────────────────────

  class Loader
    def initialize(data, proc_arg, freeze: false)
      if data.respond_to?(:read)
        @data = data.read.b rescue ''.b
        raise EOFError, "end of file reached" if @data.empty?
      else
        @data = data.b rescue data.dup.force_encoding('BINARY')
      end
      @pos      = 0
      @symbols  = []   # index → symbol
      @objects  = []   # index → object
      @proc     = proc_arg
      @freeze   = freeze
    end

    def load
      major = read_byte
      minor = read_byte
      if major != MAJOR_VERSION
        raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
      end
      if minor > MINOR_VERSION
        raise TypeError, "incompatible marshal file format (can't be read)\n\tformat version #{MAJOR_VERSION}.#{MINOR_VERSION} required; #{major}.#{minor} given"
      end
      read_object
    end

    private

    def read_byte
      raise ArgumentError, "marshal data too short" if @pos >= @data.bytesize
      b = @data.getbyte(@pos)
      @pos += 1
      b
    end

    def read_bytes(n)
      raise ArgumentError, "marshal data too short" if @pos + n > @data.bytesize
      s = @data.byteslice(@pos, n)
      @pos += n
      s
    end

    def peek_byte
      raise ArgumentError, "marshal data too short" if @pos >= @data.bytesize
      @data.getbyte(@pos)
    end

    def read_long
      b = read_byte
      if b == 0
        0
      elsif b > 4
        b - 5
      elsif b < 252
        # negative
        n = b - 256
        n + 5
      elsif b == 1
        read_byte
      elsif b == 2
        a = read_byte; bb = read_byte
        a | (bb << 8)
      elsif b == 3
        a = read_byte; bb = read_byte; c = read_byte
        a | (bb << 8) | (c << 16)
      elsif b == 4
        a = read_byte; bb = read_byte; c = read_byte; d = read_byte
        a | (bb << 8) | (c << 16) | (d << 24)
      elsif b == 255
        a = read_byte
        a - 256
      elsif b == 254
        a = read_byte; bb = read_byte
        v = a | (bb << 8)
        v >= 0x8000 ? v - 0x10000 : v
      elsif b == 253
        a = read_byte; bb = read_byte; c = read_byte
        v = a | (bb << 8) | (c << 16)
        v >= 0x800000 ? v - 0x1000000 : v
      elsif b == 252
        a = read_byte; bb = read_byte; c = read_byte; d = read_byte
        v = a | (bb << 8) | (c << 16) | (d << 24)
        v >= 0x80000000 ? v - 0x100000000 : v
      else
        raise ArgumentError, "marshal data too short"
      end
    end

    def track(obj)
      idx = @objects.size
      @objects << obj
      idx
    end

    def read_object
      type = read_byte.chr

      case type
      when TYPE_NIL    then call_proc(nil)
      when TYPE_TRUE   then call_proc(true)
      when TYPE_FALSE  then call_proc(false)
      when TYPE_INTEGER
        n = read_long
        call_proc(n)
      when TYPE_BIGNUM
        read_bignum
      when TYPE_FLOAT
        read_float
      when TYPE_SYMBOL
        read_symbol
      when TYPE_SYMLINK
        idx = read_long
        raise ArgumentError, "bad symbol link" if idx >= @symbols.size
        @symbols[idx]
      when TYPE_STRING
        read_string
      when TYPE_ARRAY
        read_array
      when TYPE_HASH
        read_hash(false)
      when TYPE_HASH_DEF
        read_hash(true)
      when TYPE_OBJECT
        read_object_generic
      when TYPE_STRUCT
        read_struct
      when TYPE_CLASS
        read_class_ref
      when TYPE_MODULE
        read_module_ref
      when TYPE_IVAR
        read_ivar
      when TYPE_LINK
        read_link
      when TYPE_UCLASS
        read_uclass
      when TYPE_USERDEFINED
        read_user_defined
      when TYPE_USERMARSH
        read_user_marshal
      when TYPE_EXTENDED
        read_extended
      when TYPE_REGEXP
        read_regexp
      when 'd'
        read_data_object
      else
        raise ArgumentError, "dump format error for type #{type.inspect} (#{type.ord})"
      end
    end

    def call_proc(obj)
      if @freeze
        freeze_object(obj)
      end
      if @proc
        @proc.call(obj)
      else
        obj
      end
    end

    def freeze_object(obj)
      return obj if obj.nil? || obj.equal?(true) || obj.equal?(false)
      return obj if obj.is_a?(Integer) || obj.is_a?(Symbol) || obj.is_a?(Float)
      return obj if obj.is_a?(Module) # don't freeze classes/modules
      begin; obj.freeze; rescue; end # rubocop:disable Lint/SuppressedException
      obj
    end

    def read_bignum
      sign = read_byte.chr
      num_shorts = read_long
      num_bytes = num_shorts * 2
      bytes = read_bytes(num_bytes)
      n = 0
      bytes.bytes.each_with_index do |b, i|
        n |= (b << (i * 8))
      end
      n = -n if sign == '-'
      obj = call_proc(n)
      @objects << obj
      obj
    end

    def read_float
      len = read_long
      str = read_bytes(len)
      f = case str
          when 'nan'  then Float::NAN
          when 'inf'  then Float::INFINITY
          when '-inf' then -Float::INFINITY
          else             str.to_f
          end
      track(f)
      call_proc(f)
    end

    def read_symbol
      len = read_long
      str = read_bytes(len)
      sym = str.to_sym
      @symbols << sym
      sym  # symbols not passed to proc
    end

    def read_string
      len = read_long
      str = read_bytes(len)
      s = str.dup.force_encoding(Encoding::ASCII_8BIT)
      track(s)
      call_proc(s)
    end

    def read_array
      len = read_long
      arr = Array.new(len)
      track(arr)
      len.times { |i| arr[i] = read_object }
      call_proc(arr)
    end

    def read_hash(has_default)
      len = read_long
      h = {}
      track(h)
      len.times do
        k = read_object
        v = read_object
        h[k] = v
      end
      h.default = read_object if has_default
      call_proc(h)
    end

    def read_object_generic
      klass = read_class_by_symbol
      # Validate that this is a safe type to load as 'o'
      ancestors = (klass.ancestors rescue [])
      has_io = (ancestors.include?(IO) rescue false)
      if has_io
        raise ArgumentError, "can't load class: #{klass}"
      end
      # Check it's not a subclass of IO or similar
      klass_name = klass.name.to_s rescue ''
      if klass_name == 'IO' || klass_name == 'File' || klass_name == 'BasicSocket'
        raise ArgumentError, "can't load class: #{klass}"
      end
      num_ivars = read_long

      # Read all ivar name-value pairs first
      ivars = {}
      num_ivars.times do
        name = read_object  # symbol
        val = read_object
        ivars[name] = val
      end

      # Special handling for Range (uses synthetic :excl, :begin, :end ivars)
      if klass <= Range
        excl = ivars.delete(:excl)
        range_begin = ivars.delete(:begin)
        range_end = ivars.delete(:end)
        obj = Range.new(range_begin, range_end, excl)
        track(obj)
        ivars.each { |k, v| obj.instance_variable_set(:"@#{k.to_s.delete_prefix('@')}", v) rescue nil }
        return call_proc(obj)
      end

      # Special handling for Exception (uses synthetic :mesg, :bt ivars)
      if klass <= Exception
        mesg = ivars.delete(:mesg)
        bt = ivars.delete(:bt)
        obj = klass.allocate
        track(obj)
        begin
          obj.__send__(:initialize_copy, klass.new(mesg))
        rescue
          obj.instance_variable_set(:@mesg, mesg) rescue nil
        end
        obj.set_backtrace(bt) rescue nil
        ivars.each { |k, v| obj.instance_variable_set(k.to_s.start_with?('@') ? k : :"@#{k}", v) rescue nil }
        return call_proc(obj)
      end

      obj = klass.allocate
      track(obj)
      ivars.each do |name, val|
        # Ensure ivar name starts with @
        ivar_name = name.to_s.start_with?('@') ? name : :"@#{name}"
        obj.instance_variable_set(ivar_name, val) rescue nil
      end
      call_proc(obj)
    end

    def read_struct
      klass = read_class_by_symbol
      num_members = read_long
      # Allocate without calling initialize
      obj = klass.allocate
      track(obj)
      num_members.times do
        name = read_object  # symbol
        val = read_object
        obj[name] = val rescue (obj.send(:"#{name}=", val) rescue nil)
      end
      call_proc(obj)
    end

    def read_class_ref
      len = read_long
      name = read_bytes(len)
      klass = const_from_name(name)
      obj = call_proc(klass)
      @objects << obj
      obj
    end

    def read_module_ref
      len = read_long
      name = read_bytes(len)
      mod = const_from_name(name)
      obj = call_proc(mod)
      @objects << obj
      obj
    end

    def read_class_by_name
      sym = read_object
      name = sym.is_a?(Symbol) ? sym.to_s : sym.to_s
      const_from_name(name)
    end

    def const_from_name(name)
      parts = name.split('::')
      mod = Object
      parts.each do |part|
        mod = mod.const_get(part)
      end
      mod
    rescue NameError
      raise ArgumentError, "undefined class/module #{name}"
    end

    def read_class_by_symbol
      sym = read_object  # reads TYPE_SYMBOL or TYPE_SYMLINK
      const_from_name(sym.to_s)
    end

    def read_ivar
      # The next object has instance variables attached
      read_object_for_ivar
    end

    # Read an object that has ivar wrapper — special handling to set ivars
    def read_object_for_ivar
      type = read_byte.chr

      obj = case type
            when TYPE_STRING
              len = read_long
              str = read_bytes(len)
              s = str.dup.force_encoding(Encoding::ASCII_8BIT)
              track(s)
              s
            when TYPE_ARRAY
              len = read_long
              arr = Array.new(len)
              track(arr)
              len.times { |i| arr[i] = read_object }
              arr
            when TYPE_HASH
              len = read_long
              h = {}
              track(h)
              len.times do
                k = read_object
                v = read_object
                h[k] = v
              end
              h
            when TYPE_REGEXP
              len = read_long
              src = read_bytes(len)
              opts = read_byte
              r = Regexp.new(src, opts)
              track(r)
              r
            when TYPE_USERDEFINED
              read_user_defined_body
            when TYPE_STRUCT
              read_struct_body
            when TYPE_OBJECT
              read_generic_object_body
            else
              # Push back and re-read
              @pos -= 1
              read_object
            end

      num_ivars = read_long
      enc_applied = false
      num_ivars.times do
        name = read_object  # symbol
        val = read_object
        if name == :E
          enc_applied = true
          enc = val ? Encoding::UTF_8 : Encoding::US_ASCII
          if obj.is_a?(String)
            obj.force_encoding(enc)
          elsif obj.is_a?(Regexp)
            # Encoding is already set via source
          elsif obj.is_a?(Symbol)
            # ignore
          end
        elsif name == :encoding
          enc_applied = true
          enc_name = val.is_a?(String) ? val : val.to_s
          enc = Encoding.find(enc_name) rescue Encoding::ASCII_8BIT
          if obj.is_a?(String)
            obj.force_encoding(enc)
          end
        else
          obj.instance_variable_set(name, val) rescue nil
        end
      end

      call_proc(obj)
    end

    def read_user_defined_body
      klass = read_class_by_symbol
      len = read_long
      data = read_bytes(len)
      obj = klass.send(:_load, data)
      @objects << obj
      obj
    end

    def read_struct_body
      klass = read_class_by_symbol
      num_members = read_long
      obj = klass.allocate
      @objects << obj
      num_members.times do
        name = read_object
        val = read_object
        obj[name] = val rescue (obj.send(:"#{name}=", val) rescue nil)
      end
      obj
    end

    def read_generic_object_body
      klass = read_class_by_symbol
      num_ivars = read_long
      obj = klass.allocate
      @objects << obj
      num_ivars.times do
        name = read_object
        val = read_object
        obj.instance_variable_set(name, val)
      end
      obj
    end

    def read_link
      idx = read_long
      raise ArgumentError, "bad link" if idx < 0 || idx >= @objects.size
      obj = @objects[idx]
      if @proc
        @proc.call(obj)
      else
        obj
      end
    end

    def read_uclass
      # C: subclass wrapper — the next object should be of this class
      klass = read_class_by_symbol
      read_object_with_class(klass)
    end

    def read_object_with_class(klass)
      type = read_byte.chr

      case type
      when TYPE_STRING
        len = read_long
        str = read_bytes(len)
        if klass == String || (klass.ancestors rescue []).include?(String)
          # Allocate instance of subclass
          obj = klass.allocate
          obj.replace(str.force_encoding(Encoding::ASCII_8BIT)) rescue nil
          track(obj)
          obj
        else
          obj = str.dup.force_encoding(Encoding::ASCII_8BIT)
          track(obj)
          obj
        end
      when TYPE_ARRAY
        len = read_long
        if klass == Array || (klass.ancestors rescue []).include?(Array)
          arr = klass.allocate
          arr_backing = arr
          track(arr)
          len.times { arr_backing << read_object }
          arr
        else
          arr = Array.new(len)
          track(arr)
          len.times { |i| arr[i] = read_object }
          arr
        end
      when TYPE_HASH
        len = read_long
        if klass == Hash || (klass.ancestors rescue []).include?(Hash)
          h = klass.allocate
          track(h)
          len.times do
            k = read_object
            v = read_object
            h[k] = v
          end
          h
        else
          h = {}
          track(h)
          len.times do
            k = read_object
            v = read_object
            h[k] = v
          end
          h
        end
      when TYPE_HASH_DEF
        len = read_long
        if klass == Hash || (klass.ancestors rescue []).include?(Hash)
          h = klass.allocate
          track(h)
          len.times do
            k = read_object
            v = read_object
            h[k] = v
          end
          h.default = read_object
          h
        else
          h = {}
          track(h)
          len.times do
            k = read_object
            v = read_object
            h[k] = v
          end
          read_object  # discard default
          h
        end
      when TYPE_REGEXP
        len = read_long
        src = read_bytes(len)
        opts = read_byte
        obj = if klass == Regexp || (klass.ancestors rescue []).include?(Regexp)
                klass.new(src, opts)
              else
                Regexp.new(src, opts)
              end
        track(obj)
        obj
      when TYPE_UCLASS
        # Nested C: — read inner class, combine with outer
        inner_klass = read_class_by_symbol
        read_object_with_class(inner_klass)
      when TYPE_IVAR
        # The uclass object has ivars
        read_object_with_class_ivar(klass)

      else
        @pos -= 1
        read_object
      end
    end

    def read_object_with_class_ivar(klass)
      type = read_byte.chr
      obj = case type
            when TYPE_STRING
              len = read_long
              str = read_bytes(len)
              klass_is_string = (klass <= String rescue false)
              if klass_is_string
                o = klass.allocate
                begin; o.replace(str.force_encoding(Encoding::ASCII_8BIT)); rescue; end # rubocop:disable Lint/SuppressedException
                track(o)
                o
              else
                o = str.dup.force_encoding(Encoding::ASCII_8BIT)
                track(o)
                o
              end
            when TYPE_HASH
              len = read_long
              h = klass <= Hash ? klass.allocate : {}
              track(h)
              len.times do
                k = read_object
                v = read_object
                h[k] = v
              end
              h
            else
              @pos -= 1
              read_object
            end

      num_ivars = read_long
      num_ivars.times do
        name = read_object
        val = read_object
        if name == :E
          enc = val ? Encoding::UTF_8 : Encoding::US_ASCII
          obj.force_encoding(enc) if obj.is_a?(String)
        elsif name == :encoding
          enc_name = val.is_a?(String) ? val : val.to_s
          enc = Encoding.find(enc_name) rescue Encoding::ASCII_8BIT
          obj.force_encoding(enc) if obj.is_a?(String)
        else
          obj.instance_variable_set(name, val) rescue nil
        end
      end
      call_proc(obj)
    end

    def read_user_defined
      klass = read_class_by_symbol
      len = read_long
      data = read_bytes(len)
      obj = klass.send(:_load, data)
      # If _load returns nil/immediate, treat it as nil
      @objects << obj
      call_proc(obj)
    end

    def read_user_marshal
      klass = read_class_by_symbol
      obj = klass.allocate
      track(obj)
      data = read_object
      obj.marshal_load(data)
      call_proc(obj)
    end

    def read_extended
      # e: module name is a symbol, then the object
      mod = read_class_by_symbol

      obj = read_object
      obj.extend(mod) rescue nil
      obj
    end

    def read_regexp
      len = read_long
      src = read_bytes(len)
      opts = read_byte
      r = Regexp.new(src.force_encoding(Encoding::ASCII_8BIT), opts)
      track(r)
      call_proc(r)
    end

    def read_data_object
      # Data class (Ruby 3.2+) — stored like Struct with 'S' type in newer formats
      # or as 'd' in some versions
      klass = read_class_by_symbol
      num_members = read_long
      kwargs = {}
      num_members.times do
        name = read_object
        val = read_object
        kwargs[name] = val
      end
      obj = klass.new(**kwargs)
      track(obj)
      call_proc(obj)
    end
  end

  # ─── Public API ────────────────────────────────────────────────────────────

  def dump(obj, io = nil, limit = -1)
    if io.is_a?(Integer) && limit == -1
      limit = io
      io = nil
    end
    if io && !io.respond_to?(:write)
      raise TypeError, "instance of #{io.class} needs to have method `write'"
    end
    d = Dumper.new(limit)
    result = d.dump(obj)
    if io
      io.binmode if io.respond_to?(:binmode)
      io.write(result)
      io
    else
      result
    end
  end

  def load(source, proc_arg = nil, freeze: false)
    loader = Loader.new(source, proc_arg, freeze: freeze)
    loader.load
  end
  alias restore load
end
