$LOADED_FEATURES << File.expand_path('../bench/stubs/harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../../lib/frozone/vm/wq_parser'

sources = [
  "class Foo; end",                       # empty class
  "class Foo; 1; end",                    # class with non-def body
  "class Foo; def bar; 1; end; end",      # class with def + non-empty body
  "class Foo; def bar; end; end",         # the failing one
  "def bar; end",                         # def with empty body, top-level
]

sources.each do |src|
  parser = Parser::Ruby40.new
  parser.diagnostics.consumer = ->(d) { $stderr.puts "diagnostic reason: #{d.reason.inspect}" }
  parser.diagnostics.all_errors_are_fatal = true
  buf = Parser::Source::Buffer.new("(test)", source: src)
  begin
    ast = parser.parse(buf)
    puts "#{src.inspect.ljust(40)} -> #{ast ? ast.to_sexp.gsub("\n"," ") : "NIL"}"
  rescue => e
    extra = e.respond_to?(:diagnostic) && e.diagnostic ? " reason=#{e.diagnostic.reason.inspect}" : ""
    puts "#{src.inspect.ljust(40)} -> EXCEPTION #{e.class}#{extra}"
  end
end
