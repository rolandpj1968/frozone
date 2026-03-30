# Per-generate() inputs and pre-scan results for the Codegen.
#
# Created once per generate() call. Groups the input params and
# pre-computed analysis results that are read-only during emission.

module Frozone
  module Compiler
    class CompileContext
      attr_accessor :top_level_scope     # Vm::ClassObject — Core::OBJECT_CLASS
      attr_accessor :stub_file           # String or nil — stub file path to exclude
      attr_accessor :masgn_return_methods # Set of method names called in masgn RHS
      attr_accessor :object_instance_methods # Set of methods emitted on RubyObject
      attr_accessor :user_methods        # Set of user-defined method names for stubs
      attr_accessor :method_index        # {method_name_string => index} for respond_to?
      attr_accessor :in_execute_block    # Bool — currently emitting the execute block

      def initialize(top_level_scope:, stub_file: nil)
        @top_level_scope = top_level_scope
        @stub_file = stub_file
        @masgn_return_methods = nil
        @object_instance_methods = Set.new
        @user_methods = Set.new
        @method_index = {}
        @in_execute_block = false
      end

      def bench_stub? = @stub_file&.include?('bench/stubs/')
    end
  end
end
