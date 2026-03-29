# Per-class emission state for the Codegen.
#
# Created fresh for each user class emission. Replaces the save/restore
# pattern of @current_class_* ivars on the Codegen class.

module Frozone
  module Compiler
    class ClassContext
      attr_accessor :name                # Symbol — class/module name
      attr_accessor :ivars               # {ivar_sym => :i64/:f64} — scalar-typed ivars
      attr_accessor :typed_ivars         # {ivar_sym => [:class, :Foo] / [:class_or_nil, :Foo]} — class-typed ivars
      attr_accessor :eigen_methods       # Set of eigenclass method names, or nil

      def initialize
        @name = nil
        @ivars = {}
        @typed_ivars = {}
        @eigen_methods = nil
      end
    end
  end
end
