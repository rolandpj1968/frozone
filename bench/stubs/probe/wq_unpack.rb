$LOADED_FEATURES << File.expand_path('../../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

s = "1 + 2"
puts "encoding: #{s.encoding}"
puts "encoding == UTF-8: #{s.encoding == Encoding::UTF_8}"
pts = s.unpack('U*')
puts "pts class: #{pts.class}"
puts "pts size: #{pts.size}"
puts "pts: #{pts.inspect}"
