class Object
  def hash = __id__

  def object_id = __id__

  alias send __send__
end
