$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

a = "hello"
b = "world"

# Concat (immutable)
c = a + " " + b
puts c                  # hello world

# Mutating <<
a << " there"
puts a                  # hello there

# Length (codepoints) and bytesize
puts "abc".length        # 3
puts "abc".bytesize      # 3

# Comparison
puts "abc" == "abc"      # true
puts "abc" == "abd"      # false
puts "abc" < "abd"       # true

# Indexing — single byte/char as new String
puts "hello"[0]          # h
puts "hello"[-1]         # o

# Hash key with String
h = { "foo" => 1, "bar" => 2 }
puts h["foo"]            # 1
puts h["bar"]            # 2

# String#empty?
puts "".empty?           # true
puts "x".empty?          # false
