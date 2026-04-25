$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

a = 1.5
b = 2.5
puts a + b           # 4.0
puts a * b           # 3.75
puts b - a           # 1.0
puts b / a           # 1.66667
puts a < b           # true
puts a == 1.5        # true
puts -a              # -1.5

# Float-keyed hash works via value-based hash
h = { 0.1 => :one_tenth, 0.5 => :half }
puts h[0.5]          # half
puts h[0.1]          # one_tenth
