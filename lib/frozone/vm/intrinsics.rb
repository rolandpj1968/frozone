module Frozone
  module Vm
    module Intrinsics
      # Current Frozone (simulated) thread ID: nil = main thread, otherwise the
      # object_id of the active Frozone Thread object (set by thread_save_reset_locals).
      # Single-element array so it can be mutated from class methods.
      CURRENT_FROZONE_THREAD_ID = [nil]

      class << self
      end
    end
  end
end

require_relative 'intrinsics/helpers'
require_relative 'intrinsics/object_intrinsics'
require_relative 'intrinsics/kernel_intrinsics'
require_relative 'intrinsics/random_intrinsics'
require_relative 'intrinsics/fiber_intrinsics'
require_relative 'intrinsics/proc_intrinsics'
require_relative 'intrinsics/module_intrinsics'
require_relative 'intrinsics/integer_intrinsics'
require_relative 'intrinsics/float_intrinsics'
require_relative 'intrinsics/file_intrinsics'
require_relative 'intrinsics/time_intrinsics'
require_relative 'intrinsics/regexp_intrinsics'
require_relative 'intrinsics/io_intrinsics'
require_relative 'intrinsics/string_intrinsics'
require_relative 'intrinsics/array_intrinsics'
require_relative 'intrinsics/range_intrinsics'
require_relative 'intrinsics/hash_intrinsics'
