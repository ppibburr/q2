require pkg: 'gtksourceview-3.0'
require pkg: 'gtk+-3.0'

class Repl < Gtk::Window
  signal() {
    def repl q,w;end
  }
  
  def initialize
    @title = "Replace Text"
    
    h=Gtk::Box.new(Gtk::Orientation::VERTICAL, 0)
    h.pack_start(@q=Gtk::Entry.new(), false,false,0)
    h.pack_start(@w=Gtk::Entry.new(),false,false,0)
    
    add(h)
    
    q.activate.connect() do
      # TODO: var as second nonononon
      activate()
    end
    
    w.activate.connect() do
      # TODO: var as second nonononon
      activate()
    end
  end
  
  def activate; 
    repl(q.text, "#{w.text}")
    hide()
  end
end

class EditView < Gtk::SourceView
  attr_reader(:autocomplete) {Gtk::SourceCompletionWords}
  
  property(:source_buffer, Gtk::SourceBuffer) {
    def get
      return `get_buffer() as Gtk.SourceBuffer`
    end
  }

  property(:search_text, :string) {
    def get
      return @search.settings.search_text
    end
  }

  def initialize()
    @search  = Gtk::SourceSearchContext.new(source_buffer, nil)        

    @repl = Repl.new()
    @repl.repl.connect() do |q,w|
      find(q)
      replace("#{q}","#{w}")
    end

    search.set_highlight(true)

    @_autocomplete = Gtk::SourceCompletionWords.new('main', nil)
    @_autocomplete.register(source_buffer)

    get_completion().add_provider(@_autocomplete)      

    #WordProvider.q().attach(self)
    
    connect_keys()
    
    source_buffer.modified_changed.connect() do 
      puts "modified"
      modify()
    end
  end

  def connect_keys()
    # change_number.connect() do puts "WHY" end
  
    key_press_event.connect() do |event|
      if ((event.key.state & Gtk.accelerator_get_default_mod_mask()) == (Gdk::ModifierType::CONTROL_MASK | Gdk::ModifierType::SHIFT_MASK))
  
      end

      if ((event.key.state & Gtk.accelerator_get_default_mod_mask()) == Gdk::ModifierType::CONTROL_MASK)
        if event.key.keyval == Gdk::Key::f
          show_find()
          next true
        end

        if event.key.keyval == Gdk::Key::l
          show_goto()
          next true;
        end

        if event.key.keyval == Gdk::Key::h
          p "show_repl"
          show_repl()
          next true;
        end
      end
      
      next false
    end
  end

  def go_to(offset, l)
    iter = Gtk::TextIter?.nil!
    buffer.get_iter_at_line(out(iter), l)
    iter.forward_chars(offset)
    scroll_to_iter(iter, 0, false, 0, 0)
    buffer.place_cursor(iter)
  end

  defn [:bool], :string?
  def get_selected(replace_new_line)
    start = Gtk::TextIter?.nil!
    e     = Gtk::TextIter?.nil!
    buffer.get_selection_bounds(out(start), out(e))
    selected = buffer.get_text(start, e, true)
  
    if (replace_new_line)
      return selected.chomp().replace("\n", " ")
    end

    return selected;
  end
  
  defn [:string]
  def find(txt)
    if search.settings.search_text == txt
      find_next()
    else
    
      # TODO: a,b = c 
      end_iter = Gtk::TextIter?.nil!
      start_iter = Gtk::TextIter?.nil!
      
      search.settings.search_text = txt
      
      source_buffer.get_iter_at_offset(out(start_iter), source_buffer.cursor_position)

      if perform_search(start_iter)
      else
        source_buffer.get_start_iter(out(start_iter))
        perform_search(start_iter)
      end

      find_next()
    end
  end

  def find_next()
    start_iter   = Gtk::TextIter?.nil!
    @end_iter     = Gtk::TextIter?.nil!
    end_iter_tmp = Gtk::TextIter?.nil!
    
    if buffer != nil
      source_buffer.get_selection_bounds(out(start_iter), out(end_iter));
      s=end_iter
      @end_iter = end_iter_tmp
      
      if !perform_search(s)
        source_buffer.get_start_iter(out(start_iter));
        @end_iter = s
        perform_search(start_iter);
      end
    end
  end

  def replace(q, w)
    @end_iter  = Gtk::TextIter?.nil! 
    start_iter = Gtk::TextIter?.nil!

    source_buffer.get_iter_at_offset(out(start_iter), source_buffer.cursor_position);
    search.settings.search_text = q
   
    if perform_search(start_iter)
      search.replace2(start_iter, end_iter, w, w.length)
    end
  end      
        
  defn [:string, :string]
  def replace_all(q, w)
    search.settings.search_text = q
    search.replace_all(w, w.length)
  end      
  
  def perform_search(start_iter)
    contains = search.forward2(start_iter, out(start_iter), out(end_iter), nil);

    if (contains)
      source_buffer.select_range(start_iter, end_iter);
      scroll_to_iter(start_iter, 0, false, 0, 0);
    end

    return contains
  end

  signal() { def modify();end}
  signal() { def show_find();end }
  signal() { def show_goto();end }
  signal() { 
    def show_repl()
      @repl.q.text = search_text
      @repl.show_all()
    end
  }
              
  defn [:string[]]
  def self.main args
    Gtk.init(ref(args))
    
    w=Gtk::Window.new(0)
    w.add e=EditView.new()
    
    e.buffer.text = "\n\n\nfoo\n\n\n"
    e.go_to(0,1)
    
    GLib::Timeout.add(3000) do
      e.replace_all("foo","bar")
      next false
    end
    
    w.show_all()
    
    Gtk.main()
  end
end


