# Frozone-scaled keyword_args benchmark: 5K calls instead of 5M

def add(left:, right:)
  left + right
end

run_benchmark(3) do
  5000.times do |i|
    add(left: 1, right: 0)
    add(left: 1, right: 1)
    add(left: 1, right: 2)
    add(left: 1, right: 3)
    add(left: 1, right: 4)
  end
end
