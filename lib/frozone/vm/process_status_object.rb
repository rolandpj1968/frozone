require_relative 'object_object'
require_relative 'core'
require_relative 'integer_object'

module Frozone
  module Vm
    class ProcessStatusObject < ObjectObject
      class << self
        # Translate a host Ruby `::Process::Status` into a guest
        # ProcessStatusObject. The host object stays at the boundary;
        # guest code only ever sees the extracted pid + raw status word.
        def from_native(host_status)
          new(IntegerObject.new(host_status.pid), IntegerObject.new(host_status.to_i))
        end
      end

      # pid + raw_status are guest IntegerObjects matching the @pid/@raw
      # ivars that lib/core/4.0/process.rb's Process::Status methods read.
      def initialize(pid, raw_status)
        super(Core.process_status_class)
        set_ivar(:@pid, pid)
        set_ivar(:@raw, raw_status)
      end
    end
  end
end
