$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end
require_relative '../../lib/frozone/vm/wq_parser'

# Cover the common Ruby constructs the parser must handle for
# wq_parse_smoke to be a meaningful smoke test (vs lucky on "1+2"):
# def, class, hash, conditionals, blocks.
sources = [
  "1 + 2",
  "x = 1; x * 2",
  "if a > 0 then b else c end",
  "[1, 2, 3].map { |n| n * n }",
  'def foo(x); x + 1; end',
  'class Foo; def bar; end; end',
  '{a: 1, b: 2}',
  'case x; when 1; :one; when 2; :two; else :other; end',
]

sources.each do |src|
  # Fresh parser per source — `parser.reset` may leak state in
  # the box-first build (some intrinsics in the reset chain may
  # be skipped). Easier diagnostic.
  parser = Parser::Ruby40.new
  # Fail-hard on diagnostics. At this stage of compiler development
  # we want every parser-level signal surfaced — silent diagnostics
  # mask compiler bugs that miscompile the parser into rejecting
  # well-formed source. SyntaxError#message goes through
  # Kernel#format / String#% (intrinsic :string_format) which may
  # not be implemented yet — capture the diagnostic via the consumer
  # (reason symbol only) and rescue the SyntaxError without rendering.
  parser.diagnostics.consumer = ->(d) { $stderr.puts "diagnostic reason: #{d.reason.inspect}" }
  parser.diagnostics.all_errors_are_fatal = true
  buf = Parser::Source::Buffer.new("(test)", source: src)
  begin
    ast = parser.parse(buf)
    puts ast ? ast.to_sexp.gsub("\n", " ") : "nil"
  rescue Parser::SyntaxError
    $stderr.puts "(parse failed for: #{src.inspect})"
    puts "nil"
  end
end
