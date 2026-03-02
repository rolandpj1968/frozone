module Frozone
  module Vm
    class Frame
      def initialize(the_self, locals, scopes)
        # TODO - map locals to slot number
        @locals = {}
        locals.each do |local|
          @locals[local] = NilObject::NIL
        end
        @the_self = the_self
        @scopes = scopes
      end

      def the_self = @the_self

      def get_local(local) = @locals[local]

      def set_local(local, value)
        @locals[local] = value
      end

      def scopes = @scopes
    end
  end
end
