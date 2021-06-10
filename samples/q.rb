class Foo
  def moof
    a=[1,2,3]
    return a
  end
  
  sig []
  def foo a;
    p "foo %d", a
  end
  
  dele [:int]
  def quux_cb a; end
  
  defn [:quux_cb]
  def quux &cb
    moof().each do |q|
      cb[q]
    end
    foo(33)
  end
end

class Bar < Foo
  attr_accessor(:accessor) {:int}
  attr_reader(:reader)     {:int}
  attr_writer(:writer)     {:int}
  
  property(:prop1, :int, 5)
  property(:prop2, :int)  {
    def get; return @_prop2; end
    def set; @_prop2 = value; end
  }

  defn [:int,:string]
  def initialize a,b
    p a
    @one = 1
    @_private = "no_see_me"
    p b
    p1 = moof()
    p "p1 %d",p1[1]
    @accessor = 11
    accessor = 13
    @_reader = 12
    p "foo: %d", @_accessor
    @_accessor = 14;
    p "foo: %d", @accessor
    p "foo: %d", @_reader
    p "bar: %d", @reader
    puts "each"
    moof().each do |q|
      p q
    end
    puts "for"
    for i in moof()
      p i
    end
    
    foo.connect() do |i|
      p "connect: %d",i
    end    
    
    puts "cb"
    quux do |n|
      p n
    end
    v=almost_last("ok",69)
    l = last(1)
  end
  
  def almost_last(a,b)
    p "al: %s -> %d", a,b
    return a
  end

  def last(a)
    return 69
  end
  
  # Program main entry
  defn [:string[]]
  def self.main args
    Bar.new(1,"two")
    
    p "%s: %d", $FILENAME, $LINENO
    
    Gtk.init(`ref args`)
    
    w=Gtk::Window.new(0)
    w.title = $0
    w.add(Gtk::Label.new("TTime = "+Q.tt.to_string()+"\nThis label text set at:\n"+$FILENAME+": "+$LINENO.to_string()))
    w.show_all()
    p "%s", File.read($FILENAME)
    w.delete_event.connect() do
      p "%s: %d => BYE!!", $FILENAME, $LINENO
      Gtk.main_quit()
      next false
    end
    
    Gtk.main()
  end
end
