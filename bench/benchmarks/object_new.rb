# Frozone-scaled object-new benchmark: 1K allocations instead of 1M

run_benchmark(3) do
  i = 0
  while i < 1000
    Object.new
    i += 1
  end
end
