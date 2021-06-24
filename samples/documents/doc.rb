require pkg: "vte-2.91"
require pkg: "gtk+-3.0"

namespace module Documents
  module Doc
    include Gtk::Widget

    attr_accessor(:name) {:string?}
    attr_accessor(:resource) {:string?}

    signal { 
      def closed();end
      defn [:Doc]
      def activate();end
      def activated();end
      def removed();end
    }

    def close
      closed()
      destroy()
    end
  end
  
  class Iterator
    defn [:Manager]
    def initialize mgr
      @m = mgr
      @i = 0
    end
    
    defn [], :Doc?
    def next_value
      if @i < m.list.length
        @i = @i+1
        return m.list[@i-1]
      end
      
      return nil
    end
  end  
  
  module Manager
    include Object
    
    defn [:string],:int
    def find n
      i = 0
      @list.each do |d|
        return i if d.name==n  
        i = i+1
      end
      return -1    
    end
    
    defn [:string],:Doc?
    def [] n
      i = find(n)
      return @list[i] if i >= 0
      return nil
    end
    
    defn [:string, :Doc]
    def []= n,d
      d.name = n
    
      i = find(n)
      if i >= 0
        @list[i] = d
      else
        add(d)
        i = @list.length-1        
      end
      
      d.activate.connect() do |q|
        activate(q)
      end 
      
      activate(d) if i == @list.length-1
    end
    
    defn [:Doc]
    def activate d
      d.activated()
      changed(d)
    end
    
    attr_reader(:active) {:int}
    attr_reader(:list) {:Doc[]}
    
    def cycle;
      if @active < @list.length-1
        @list[@active+1].activate()
      else
        @list[0].activate() if @list.length > 0
      end
    end
    
    defn [:Doc]
    def remove d;
      removed(d)
      d.activate.disconnect(on_activate_document)
      d.removed() 
      cycle()  
    end
    
    defn [:Doc]
    def on_activate_document d
      activate(d)
    end
    
    defn [:Doc]
    def add d;
      d.activate.connect(on_activate_document)    
      added(d)
    end
    
    defn [:string], :bool
    def contains n
      return find(n) >= 0
    end
    
    defn [], :Iterator
    def iterator
      return Iterator.new(self)
    end
    
    signal {
      def changed d; end
      def added d; end
      def removed d;end
    }
  end
  
  class MyMGR < Gtk::Notebook
    include Manager
   
    attr_reader(:active) {:int}
    attr_reader(:list) {:Doc[]}
    attr_reader(:size) {:int}
    
    def initialize
      @_list = :Doc[].nil!
      @_list = []
      @_active = -1
    
      removed.connect() do |d|
        i = find(d.name)
        
        a = list[0..i] if i > 0
        b = list[(i+1)..list.length]
                
        b.each do |q|
          a << q
        end
        
        @_list = a
      end
    
      added.connect() do |d|
        @_list << d
        append_page `(Gtk.Widget)d`, Gtk::Label.new(d.name)
      end
      
      changed.connect() do |d|
        @_active = find(d.name)
        @page = @active
      end
    end
  end 
  
  class MyDoc < Gtk::Box
    attr_accessor(:name) {:string?}
    attr_accessor(:resource) {:string?}
    include Doc
  end
  
  defn [:string[]]
  def self.test args
    Gtk.init(ref(args))
    
    m=MyMGR.new()
    m.added.connect() do |d| 
      p "add: %s", d.name 
    
      d.activated.connect do
        p "activate"
      end
    
      d.removed.connect() do
        d.close()
      end
    
      d.closed.connect do 
        p "closed"
      end      
    end
    
    m.changed.connect() do |d| p "chg: %s", d.name end
    m.removed.connect() do |d| p "rem: %s", d.name end
    
    m["Foo"]  = MyDoc.new
    m["Foo1"] = MyDoc.new
    m["Foo2"] = MyDoc.new
    m["Foo3"] = MyDoc.new
    
    m.each do |q|
      p q.name
    end
    
    GLib::Timeout.add(3000) do
      m.remove(m["Foo"])
      next false
    end
    
    GLib::Timeout.add(1000) do
      m.cycle()
      next true
    end
    
    w=Gtk::Window.new()
    w.add m
    w.show_all()
    
    w.resize(600,600)
    
    Gtk.main()
  end
end