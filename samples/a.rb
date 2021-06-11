
generics :G, :T
class OtherA
  defn [:G,:T]
  def initialize g,_t
    @t = _t
    p "file a: %s", g
    p DATA.read
  end
 
  def rt
    p "five "+5
    p "five "+3.33
    p 3.33+5
    p 5+" five"
    x = "three " + 3
    y = x + " two"
    z = Value(" FI5E")
    p "value: " + z
    q = Value(420.0)
    p q+0.69

    return @t
  end
end

__END__
othera
data read
