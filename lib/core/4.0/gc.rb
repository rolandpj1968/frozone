module GC
  @disabled = false
  @gc_count = 0
  @major_gc_count = 0
  @auto_compact = false
  @measure_total_time = false
  @stress = false
  @config = { implementation: "default", rgengc_allow_full_mark: true }.freeze

  STAT_KEYS = %i[count heap_allocated_pages heap_sorted_length heap_allocatable_pages
                 heap_available_slots heap_live_slots heap_free_slots heap_final_slots
                 heap_marked_slots heap_eden_pages heap_tomb_pages total_allocated_pages
                 total_freed_pages total_allocated_objects total_freed_objects
                 malloc_increase_bytes malloc_increase_bytes_limit minor_gc_count
                 major_gc_count remembered_wb_unprotected_objects
                 remembered_wb_unprotected_objects_limit old_objects old_objects_limit
                 oldmalloc_increase_bytes oldmalloc_increase_bytes_limit].freeze

  def self.count = @gc_count
  def self.auto_compact = @auto_compact
  def self.measure_total_time = @measure_total_time
  def self.total_time = 0
  def self.stress = @stress

  def self.start(**opts)
    @gc_count += 1
    @major_gc_count += 1
    nil
  end

  def self.enable
    was_disabled = @disabled
    @disabled = false
    was_disabled
  end

  def self.disable
    was_disabled = @disabled
    @disabled = true
    was_disabled
  end

  def self.stat(key = nil)
    values = {
      count: @gc_count,
      heap_allocated_pages: 0, heap_sorted_length: 0, heap_allocatable_pages: 0,
      heap_available_slots: 0, heap_live_slots: 0, heap_free_slots: 0, heap_final_slots: 0,
      heap_marked_slots: 0, heap_eden_pages: 0, heap_tomb_pages: 0,
      total_allocated_pages: 0, total_freed_pages: 0,
      total_allocated_objects: 0, total_freed_objects: 0,
      malloc_increase_bytes: 0, malloc_increase_bytes_limit: 0,
      minor_gc_count: @gc_count, major_gc_count: @major_gc_count,
      remembered_wb_unprotected_objects: 0, remembered_wb_unprotected_objects_limit: 0,
      old_objects: 0, old_objects_limit: 0,
      oldmalloc_increase_bytes: 0, oldmalloc_increase_bytes_limit: 0
    }
    if key.nil?
      values
    elsif key.is_a?(Hash)
      key.each_key do |k|
        key[k] = values[k] if values.key?(k)
      end
      key
    elsif key.is_a?(Symbol)
      raise ArgumentError, "unknown key: #{key}" unless values.key?(key)
      values[key]
    else
      raise TypeError, "non-hash or symbol given"
    end
  end

  def self.auto_compact=(val)
    @auto_compact = val ? true : false
  end

  def self.measure_total_time=(val)
    @measure_total_time = val ? true : false
  end

  def self.compact
    { considered: {}, moved: {} }
  end

  def self.config(opts = nil)
    return @config.dup if opts.nil?
    if opts.respond_to?(:to_hash)
      opts = opts.to_hash
    end
    if opts.is_a?(Hash)
      opts.each_key do |k|
        if k == :implementation
          raise ArgumentError, 'Attempting to set read-only key "Implementation"'
        end
      end
      # Only merge keys that exist in current config (ignore unknown keys)
      # Boolean keys are coerced to true/false
      bool_keys = %i[rgengc_allow_full_mark auto_compact measure_total_time]
      known_opts = {}
      opts.each do |k, v|
        next unless @config.key?(k) && k != :implementation
        known_opts[k] = bool_keys.include?(k) ? (v ? true : false) : v
      end
      @config = @config.merge(known_opts).freeze
      return @config.dup
    end
    raise ArgumentError, "wrong argument type #{opts.class} (expected Hash or nil)"
  end

  def self.stress=(val)
    @stress = val ? true : false
  end

  def garbage_collect(**opts)
    GC.start
    nil
  end
  module Profiler
    @enabled = false

    def self.enabled? = @enabled
    def self.clear; end
    def self.result = ""
    def self.report(io = nil); end
    def self.total_time = 0.0

    def self.enable
      @enabled = true
    end

    def self.disable
      @enabled = false
    end
  end
end
