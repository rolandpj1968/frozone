# Minimal PP stub. The real pp.rb is blocked from loading via $LOADED_FEATURES
# because it uses default-param tricks Frozone's evaluator cannot handle.
# mspec only needs pretty_inspect (defined on Object in object.rb) and PP.pp.
class PP
  def self.width_for(_out) = 80

  def self.pp(obj, out = nil, width = 80)
    str = obj.pretty_inspect
    str = "#{str}\n" unless str.end_with?("\n")
    if out.nil?
      $stdout.print str
    else
      out << str
    end
    obj
  end
end

