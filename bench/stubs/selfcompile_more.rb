$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

require_relative '../../lib/frozone/ast/integer_literal'
require_relative '../../lib/frozone/ast/string_literal'
require_relative '../../lib/frozone/ast/local_variable_read'
require_relative '../../lib/frozone/ast/local_variable_write'
require_relative '../../lib/frozone/ast/method_call'

x = 42
puts "loaded #{x} ast nodes"
