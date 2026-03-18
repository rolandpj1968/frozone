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

  module WeakMap
  end
end
