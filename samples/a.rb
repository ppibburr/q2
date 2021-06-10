
generics :G, :T
class OtherA
  defn [:G,:T]
  def initialize g,_t
    @t = _t
    p "file a: %s", g
  end
 
  def rt
    return @t
  end
end

