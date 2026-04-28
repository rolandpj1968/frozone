result = catch(:done) do
  [1, 2, 3, 4, 5].each do |n|
    throw :done, n * 10 if n == 3
  end
  :not_thrown
end
puts result
