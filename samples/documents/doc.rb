require pkg: "vte-2.91"
require pkg: "gtk+-3.0"

namespace
module Q
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
      def left();end
    }

    def close
      closed()
    end
  end
  
  module DocWriter
    include Gtk::Widget
    include Doc
    
    attr_accessor(:is_modified) {bool}
    
    def close
      close_modified() if @is_modified
      closed()     unless @is_modified
    end
    
    signal() { 
      def modified; end
      def close_modified; end
    }
  end
  
  class Iterator
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
    
    attr_reader(:list) {Q::Doc?[]}
    attr_reader(:active) {int}
    
    def find r
      i = 0
      
      @list.each do |d|
        return i if d.resource==r  
        i = i+1
      end
      
      return -1    
    end
    
    defn [:string],:Doc?
    def [] r
      i = find(r)
      return @list[i] if i >= 0
      return nil
    end
    
    defn [:string, :Doc]
    def []= r,d
      d.resource = r
    
      i = find(r)
      if i >= 0
        @list[i] = d
      else
        add(d)
        i = @list.length-1        
      end
      

      activate(d) if i == @list.length-1
    end
    

    def activate d
      d.activated()
      changed(d) unless @active == find(d.resource)
    end
        
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
      
      cycle() if @active == find(d.resource) 
    end
    
    defn [:Doc]
    def on_activate_document d
      if @list[@active] != d
        if @list[@active]
          @list[@active].left()
        end
        activate(d)
      end
    end
    
    def add d;
      d.activate.connect(on_activate_document) 
      d.closed.connect do remove(d) end   
      added(d)
    end
    
    def document_at_index i
      return @list[i]
    end  
    
    def active_document()
      return document_at_index(@active) if @active >= 0
      return nil
    end
        
    defn [:string], :bool
    def contains n
      return find(n) >= 0
    end   
    
    def iterator
      return Iterator.new(self)
    end
    
    signal {
      def changed d; end
      def added d; end
      def removed d;end
    }
  end
  
  ## A Gtk::ListBox ::Manager Switcher
  ##
  ## switches and updates state of Manager#active
  class DocumentListSwitcher < Gtk::ListBox
    attr_reader(:mgr) {Manager}
    
    defn [Manager]
    def initialize(stack)
      @_mgr = stack

      ## Activate the Doc at index in the Manager#list
      row_activated.connect() do |l,c|
        Doc.cast!(@mgr.list[child_index(c)]).activate() unless @mgr.active == child_index(c)
      end
      
      ## Update List items on Manager#added and set selection
      @mgr.added.connect_after() do |d|  
        add(d.name)
        select_row(get_row_at_index(@mgr.active))
      end
      
      ## Update List items on Manager#removed
      @mgr.removed.connect() do |d|
        i = @mgr.find(d.resource)
        remove(get_children().nth(i).data)
      end
      
      ## Update List selection on Manager#changed
      @mgr.changed.connect_after() do
        @has_focus = true
        grab_focus()
        p "select row: #{@mgr.active}"
        row = get_row_at_index(@mgr.active)
        select_row(row) #if (row != get_selected_row())
      end
    end
    
    defn [Gtk::Widget?], int
    ## Gets the index of a row +c+
    def child_index c
      l = get_children().length()
      for i in 0..(l-1)
        return i if get_children().nth(i).data == c
      end
      
      return -1
    end
    
    defn [string]
    ## Adds label +n+ to children
    def add n
      new!
      
      Gtk::ListBox.cast!(self).add Gtk::Label.new(n)
      show_all()
    end
  end  
  
  class DocumentStack < Gtk::Stack
    include Manager
 
    attr_reader(:active) {:int}
    attr_reader(:list) {Doc[]}
    attr_reader(:size) {:int}        
        
    def initialize
      notify['visible-child-name'].connect_after do
        doc = Doc.cast!(get_child_by_name(visible_child_name))
        return if @list[@active] == doc
        activate(doc)
      end   
      
      changed.connect_after() do |d|
        q = find(d.resource)

        p "q: #{q} i: #{@active}"

        if q >= 0
          @_active = q
        end   
        
        if self.visible_child_name != d.name
          self.visible_child_name = d.name 
        end
      end
      
      added.connect() do |d|
        @_list << d
 
        @_active = find(d.resource)
        
        add_named d,d.name
      
        changed(d)
      end
      
      removed.connect_after() do |d|
        i = find(d.resource)
  
        a = list[0..i]
        b = list[(i+1)..list.length]
   
        b.each do |q|
          a << q
        end

        @_list = a
      end      
    end
  end  
  
  class DocBook < Gtk::Notebook
    include Manager
   
    attr_reader(:active) {:int}
    attr_reader(:list) {:Doc[]}
    attr_reader(:size) {:int}
    
    def initialize
      @_list = :Doc[].nil!
      @_list = []
      @_active = -1
    
      @scrollable = true
    
      removed.connect() do |d|
        i = find(d.resource)
        
        a = @list[0..i]
        b = @list[(i+1)..@list.length]
                
        b.each do |q|
          a << q
        end
        
        @_list = a
      end
    
      added.connect() do |d|
        x = d.resource
        @_list << d
        @_active = @_list.length-1
        append_page `(Gtk.Widget)d`, Gtk::Label.new(d.name)
      end
      
      changed.connect() do |d|
        q = find(d.resource)
        
        if q >= 0
          @_active = q
          @page = @active if @page != @active
        end
      end
      
      switch_page.connect() do |pg, i|
        if @list[i] != nil
          @list[i].activate() if i != @active
        end
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
    
    m=DocBook.new()
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
