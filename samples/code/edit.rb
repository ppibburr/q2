require pkg: 'gtksourceview-3.0'
require pkg: 'gtk+-3.0'
require pkg: 'gio-2.0'

require q: '/home/ppibburr/json.rb'

namespace
module Qode
  class FindTextDialog < Gtk::Window
    signal() {
      def find q;end
    }
    
    def initialize
      @title = "Find Text"
      
      h=Gtk::Box.new(Gtk::Orientation::VERTICAL, 0)
      h.pack_start(@q=Gtk::Entry.new(), false,false,0)
            
      add(h)
      
      q.activate.connect() do
        activate()
      end
      
      delete_event.connect() do
        hide()
        next true
      end
    end
    
    def activate; 
      find(q.text)
    end
  end

  class GotoDialog < Gtk::Window
    signal() {
      def go_to q;end
    }
    
    def initialize
      @title = "GoTo Line"
      
      h=Gtk::Box.new(Gtk::Orientation::VERTICAL, 0)
      h.pack_start(@q=Gtk::SpinButton.new_with_range(0, 16000, 1), false,false,0)
            
      add(h)
      
      q.value_changed.connect() do
        activate()
      end
    end
    
    def activate; 
      hide()
       go_to(q.get_value_as_int())         
    end
  end
  
  class ReplaceTextDialog < Gtk::Window
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
      repl(@q.text, "#{w.text}")
      hide()
    end
  end

  class EditView < Gtk::SourceView
    attr_reader(:autocomplete) {Gtk::SourceCompletionWords}
    
    property(:source_buffer, Gtk::SourceBuffer) {
      def get
        return Gtk.SourceBuffer.cast!(get_buffer())
      end
    }

    property(:search_text, :string) {
      def get
       
        if !@search.settings.search_text
          return ""
        else
          return @search.settings.search_text
        end
      end
    }
    
    def initialize()
      set_wrap_mode(Gtk::WrapMode::NONE)
    
      provider = Gtk::CssProvider.new();
      provider.load_from_data("textview { font-family: Monospace; font-size: 10pt; }",  -1);
      get_style_context().add_provider(provider,Gtk::STYLE_PROVIDER_PRIORITY_USER)
    
      @search  = Gtk::SourceSearchContext.new(source_buffer, nil)        

      search.settings.search_text = ""

      @repl = ReplaceTextDialog.new()
      @repl.repl.connect() do |q,w|
        find(q)
        replace("#{q}","#{w}")
      end

      @finder = FindTextDialog.new()
      @finder.find.connect() do |q|
        find(q)
      end
     
      @go2 = GotoDialog.new()
      @go2.go_to.connect() do |q|
        go_to(0,q)
      end      

      search.set_highlight(true)

      @_autocomplete = Gtk::SourceCompletionWords.new('main', nil)
      @_autocomplete.register(source_buffer)

      get_completion().add_provider(@_autocomplete)      

      set_wrap_mode(Gtk::WrapMode::NONE);
      @buffer.text = "";
     
      @show_line_numbers = true
      @show_line_marks   = true
      @insert_spaces_instead_of_tabs = true
      @indent_width = 2
      @highlight_current_line = true
      @auto_indent = true

      @_scheme = 0
      @_scheme = -1

      source_buffer.style_scheme = Gtk::SourceStyleSchemeManager.get_default().get_scheme('tango')
     
      @language_manager = Gtk::SourceLanguageManager.get_default();

      #WordProvider.q().attach(self)
      
      connect_keys()
      
      source_buffer.modified_changed.connect() do 
        modify()
      end
    end

  def cycle_theme()
    @_scheme = @_scheme+1
    sm=Gtk::SourceStyleSchemeManager.get_default()
    ids=sm.get_scheme_ids()
    @_scheme = 0 if @_scheme >= ids.length   
    id = ids[@_scheme]
    p "id: #{id}"
    source_buffer.style_scheme = sm.get_scheme(id)
  end

  def connect_keys()
    # change_number.connect() do puts "WHY" end
  
    key_press_event.connect() do |event|
      if ((event.key.state & Gtk.accelerator_get_default_mod_mask()) == (Gdk::ModifierType::CONTROL_MASK | Gdk::ModifierType::SHIFT_MASK))
        if event.key.keyval == Gdk::Key::T
          cycle_theme()
            next true
         end
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

          if event.key.keyval == Gdk::Key::t
            p "show_tags"
            show_tags()
            next true;
          end
        end
        
        next false
      end
    end
    
    defn [:int,:int]
    def go_to(offset, l)
        l = l - 1
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
    
      if (!!replace_new_line)
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
      
      if buffer
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
     
      if !!perform_search(start_iter)
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
    
    def show_tags()
      b=Gtk::TextBuffer.cast!(source_buffer)
      t=b.text
      
      if @tw
        @tw.destroy()
      end
      
      @tw = Q::TagWindow.new()
      
      @tw.view.activate.connect() do |tag|
        go_to(0, tag.line)
      end
      
      @tw.spawn(t)
    end

    signal() { 
      def modify();end
    
      def show_find();
        @finder.q.text = @search_text

        @finder.show_all()   
        @finder.present()
      end
      
      def show_goto();
        @go2.show_all()  
        @go2.present()  
      end
      
      def show_repl()
        @repl.q.text = @search_text
        @repl.show_all()
        @repl.present()
      end
    }
  end
end

