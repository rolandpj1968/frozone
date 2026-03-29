# Shim for spec_helper.rb — loaded via -r before the actual spec file.
# Prevents loading real mspec and provides enough API surface for compilation.

# Pre-register all possible spec_helper paths so require_relative is a no-op.
# The language specs do: require_relative '../spec_helper'
# The core specs do:     require_relative '../../spec_helper'
# __dir__ = .../frozone/bench, so go up one level to frozone/, then into spec/ruby-spec
frozone_root = File.dirname(__dir__)
spec_dir = File.join(frozone_root, 'spec', 'ruby-spec')
$LOADED_FEATURES << File.join(spec_dir, 'spec_helper.rb')
$LOADED_FEATURES << File.join(spec_dir, 'spec_helper')

# Also block mspec and its submodules
$LOADED_FEATURES << 'mspec'
$LOADED_FEATURES << 'mspec.rb'
$LOADED_FEATURES << 'mspec/commands/mspec-run'
$LOADED_FEATURES << 'mspec/commands/mspec-run.rb'

# CODE_LOADING_DIR used by some specs
CODE_LOADING_DIR = File.join(spec_dir, 'fixtures', 'code')

# Load the actual test harness
require_relative 'test_harness'
