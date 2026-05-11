def kw_one(a:)
  a * 10
end

def kw_two(a:, b:)
  a * 100 + b
end

def pos_and_kw(p, q, a:, b:)
  p + q + a * 100 + b
end

puts kw_one(a: 5)
puts kw_two(a: 3, b: 7)
puts kw_two(b: 7, a: 3)
puts pos_and_kw(1, 2, a: 4, b: 8)
puts pos_and_kw(1, 2, b: 8, a: 4)

h = { a: 4, b: 8 }
puts pos_and_kw(1, 2, **h)
