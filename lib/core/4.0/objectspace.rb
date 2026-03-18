module ObjectSpace
  def self.each_object(klass = nil, &block) = Intrinsics.objectspace_each_object(klass, block)
  def self.define_finalizer(obj, proc_arg = nil, &block) = Intrinsics.objectspace_define_finalizer(obj, proc_arg, block)
  def self.undefine_finalizer(obj) = Intrinsics.objectspace_undefine_finalizer(obj)
  def self._id2ref(id) = Intrinsics.objectspace_id2ref(id)
  def self.count_objects(result = nil) = Intrinsics.objectspace_count_objects(result)

  module WeakMap
  end
end
