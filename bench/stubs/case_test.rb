$LOADED_FEATURES << File.expand_path('../harness/loader.rb', __dir__)
def run_benchmark(*, &); end

def grade(score)
  case score
  when 90 then "A"
  when 80 then "B"
  when 70 then "C"
  when 60 then "D"
  else         "F"
  end
end

def category(n)
  case n
  when 1, 2, 3 then "low"
  when 4, 5, 6 then "mid"
  else              "high"
  end
end

# case-without-subject
def sign(n)
  case
  when n < 0  then "neg"
  when n == 0 then "zero"
  else             "pos"
  end
end

# ---- Execute ----
puts grade(90)         # A
puts grade(70)         # C
puts grade(50)         # F

puts category(1)       # low
puts category(5)       # mid
puts category(99)      # high

puts sign(-3)          # neg
puts sign(0)           # zero
puts sign(7)           # pos
