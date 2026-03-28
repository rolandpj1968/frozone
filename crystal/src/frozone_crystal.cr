require "./ruby_object"
require "./ruby_exception"
require "./ruby_bool"
require "./ruby_nil"
require "./ruby_integer"
require "./ruby_float"
require "./ruby_string"
require "./ruby_symbol"
require "./ruby_array"
require "./ruby_range"
require "./ruby_proc"
require "./ruby_hash"
require "./ruby_tuple"
require "./encoding/single_byte_tables"
require "./encoding/single_byte_transcoder"
require "./ruby_math"
require "./ruby_random"

# Multiple-assignment coercion: ensure value is an array for destructuring.
def masgn_coerce(val : RubyObject) : RubyArray
  val.is_a?(RubyArray) ? val.as(RubyArray) : RubyArray.new([val] of RubyObject)
end

def masgn_coerce(val : RubyArray) : RubyArray
  val
end
