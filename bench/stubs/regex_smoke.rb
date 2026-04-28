str = "hello-42 world"
md = str.match(/([a-z]+)-(\d+)/)
if md
  puts md[0]
  puts md[1]
  puts md[2]
end

idx = "abc123" =~ /\d+/
puts idx.nil? ? "nil" : idx

if "foo bar baz" =~ /(\w+) (\w+)/
  puts $1
  puts $2
end
