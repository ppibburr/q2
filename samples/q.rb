class Foo
  def moof
    a=[1,2,3]
    return a
  end
  
  sig [:int]
  def foo a;
    p "foo %d", a
  end
  
  dele [:int]
  def quux_cb a; end
  
  defn [:quux_cb]
  def quux &cb
    moof.each do |q|
      cb[q]
    end
    foo(33)
  end
end

class Bar < Foo
  attr_accessor(:accessor) {:int}
  attr_reader(:reader)     {:int}
  attr_writer(:writer)     {:int}
  
  property(:prop1, :int, 5) {
    def get; return @_prop1; end
    def set; @_prop1 = @value; end
  }

  defn [:int,:string]
  def initialize a,b
    p a
    p b
    @accessor = 11
    @_reader = 12
    p "foo: %d", @_accessor
    @_accessor = 14;
    p "foo: %d", @accessor
    p "foo: %d", @_reader
    p "bar: %d", @reader
    puts "each"
    moof.each do |q|
      p q
    end
    
    puts "for"
    for i in moof
      p i
    end
    
    @foo.connect() do |i|
      p "connect: %d",i
    end    
    
    puts "cb"
    quux do |n|
      p n
    end
  end
  
  def self.main
    Bar.new(1,"two")
  end
end
