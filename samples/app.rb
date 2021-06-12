require 'Q'
require pkg: 'gtk+-3.0'

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
    end
    
    # TODO: derive 'set' and 'get' from []= and []
    
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
