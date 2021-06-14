require 'Q'
require pkg: 'gtk+-3.0'

class Foo
  #signal {
  #  def foo a
  #     p "'Im a signal!', #{a}"
  #     return 1
  #  end
  #
  #  def moof;end
  #}

  #delegate {
  #  defn [:int], :string
  #  def quux a; end
  #}
  
  def bar
    #foo "hi"
    return 0.88
  end
end



namespace module Q
  generics :T
  class App < Gtk::Window
    # TODO: string quotes appear in type
    attr_reader(:t) {`T[]`}
    def initialize
      @_t = []
      # TODO: chain
      super
      #self.title="window"
      
      add(l=Gtk::Label.new("Hello"))
      
      delete_event.connect() do
        Gtk.main_quit()
        next false
      end
      
      x = Foo.new()
      b = x.bar()
    end
        
    # not much we can do
    defn [:int,:T]
    def []= i,t
      # TODO: << = +=
      @_t << t
    end
    
    # TODO: resolve array member type
    # TODO: returns typed of array member
    defn [:int], :T
    def [] i
      return @_t[i]
    end
  end
  

end

# TODO: ref
Gtk.init(ref(Q_ARGV))
app=GenericType(Q::App,:string).new()
app[0] = "three three"
p app[0]
app.show_all()
Gtk.main()
