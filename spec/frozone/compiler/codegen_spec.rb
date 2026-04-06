require_relative '../../support/vm_loader'
require_relative '../../../lib/frozone/compiler/codegen'

RSpec.describe Frozone::Compiler::Codegen do
  describe Frozone::Compiler::CrystalTypeMapper do
    # CrystalTypeMapper integration is verified by compilation smoke tests.
    # Type-level unit tests live in type_spec.rb and type_inference_spec.rb.
  end
end
