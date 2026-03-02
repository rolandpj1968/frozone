def fibonacci(n)
  if n <= 1
    n
  else
    fibonacci(n - 1) + fibonacci(n - 2)
  end
end

N = 30

# ruby
# result = 0
# 300.times {
#   result = fibonacci(N)
# }
# puts result

# frozone (for now)
fibonacci(N)
