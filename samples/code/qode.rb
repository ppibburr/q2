require pkg: 'gio-2.0'
require pkg: 'glib-2.0'
require pkg: 'gtk+-3.0'

require q: 'samples/documents/doc.rb'
require q: 'samples/qte/qte.rb'
require q: 'samples/code/edit.rb'
require q: 'samples/application.rb'
require q: 'samples/keys.rb'

namespace 
module Qode
  defn [], Gtk::Window
  def self.toplevel()
    return Gtk::Window.list_toplevels().nth(0).data
  end

  def self.message m
    md = Gtk::MessageDialog.new(toplevel(), 
                                Gtk::DialogFlags::MODAL,
                                Gtk::MessageType::INFO,
                                Gtk::ButtonsType::OK, m)
    md.run()
    md.destroy()  
  end
  
  class InfoWidget < Gtk::InfoBar
    def initialize
      @label = Gtk::Label.new("The file has been externally modified: Press OK to reload, cancel to overwrite")      
      
      get_content_area().add(label)
      add_button("_OK", Gtk::ResponseType::OK);
      set_show_close_button(true)    
      show_all()
    end
  end

  class Document < Gtk::Grid
    include Q::Doc
    include Q::DocWriter
    include Q::KeyBinder
    
    attr_accessor(:name) {:string?}
    attr_accessor(:resource) {:string?}
    attr_reader(:view) {Qode::EditView}
    attr_accessor(:is_modified) {bool}

    def initialize
      @_view       = EditView.new()
      @info_widget = InfoWidget.new()
      @notified    = !true
      @saved_buffer = Gtk::SourceBuffer.new(nil)      
      @temp_buffer  = Gtk::SourceBuffer.new(nil)
      
      GLib::Timeout.add(500) do      
        check_external_modify()
        next true
      end
      
      set_hexpand(true)
      set_vexpand(true)

      @info_widget.response.connect() do |r|
        if r == Gtk::ResponseType::OK
          open_file(@file.location.get_path())
        else
          save_file()
        end
        
        remove_row(0)       
          
        @notified = false
      end
          
      @view.modify.connect() do 
        @is_modified = @view.source_buffer.get_modified()
        modified() if @is_modified
        @name     = File.basename(@resource) unless @is_modified
      end     
      
      @scrolled_window = Gtk::ScrolledWindow.new(nil,nil)
      @scrolled_window.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC);
      @scrolled_window.add(@view)
      
      @scrolled_window.set_hexpand(true)
      @scrolled_window.set_vexpand(true)
          
      attach(@scrolled_window, 0, 0, 1, 1);   
      
      closed.connect_after do destroy() end 
      
      close_modified.connect() do
        Qode.message("Close modified document?")
      end
            
      connect_keys()
      
      ctrl_shift_key_press.connect do |k|
        if k==Gdk::Key::W
          @is_modified = false
          close()
          next true
        end
        next false
      end     
    end
    
    def close
      override!
      Q::DocWriter.cast!(self).close()
    end
    
    def notify_modify()
      return if notified # TODO: $gt @
      @notified = true
      insert_row(0)
      @info_widget.show()
      p "we did it! - steve"
      attach(@info_widget,      0, 0, 1, 1);     
    end   

    defn [string]
    def open_file(f)
      @file = Gtk::SourceFile.new()
      @file.location = `File.new_for_path(f)`
      if (view.language_manager.guess_language(@resource,nil) == nil)
        lang = view.language_manager.get_language("")
        if f =~ /\.q$/
          lang = view.language_manager.get_language("ruby");
        end
        if f =~ /\.plugin$/
          lang = view.language_manager.get_language("ini");
        end
        if lang
          view.source_buffer.set_language(lang);
        end
      else
        view.source_buffer.set_language(view.language_manager.guess_language(@resource,nil))       
      end
      
      file_loader = Gtk.SourceFileLoader.new(view.source_buffer, file);         
      file_loader.load_async.begin(Priority::DEFAULT, nil, nil) do
        @saved_buffer.text = view.source_buffer.text
        view.source_buffer.set_modified(false)
        @name     = File.basename(@resource)  
      end
      show_all()
    end
    
    def save_file()
      if !file
        save_file_as()
        return
      end
      
      if ((file != nil) && !file.is_readonly())
        file_saver = Gtk.SourceFileSaver.new(view.source_buffer, file);
        file_saver.save_async.begin(Priority::DEFAULT, nil, nil);
        @saved_buffer.text = view.source_buffer.text
        @resource = file.location.get_path()
        @name     = File.basename(@resource)    
        view.source_buffer.set_modified(false)  
          
      else
        message("Could not write file: #{file.location.get_path()}")
      end
    end
  
    def save_file_as()
      chooser = Gtk::FileChooserDialog.new(
          "Select a file to edit", toplevel(), Gtk::FileChooserAction::SAVE,
          "_Cancel",
          Gtk::ResponseType::CANCEL,
          "_Open",
          Gtk::ResponseType::ACCEPT);

      chooser.set_select_multiple(false);
      chooser.run();
      chooser.close();

      @file = Gtk::SourceFile.new
      @file.location = chooser.get_file()
    
      save_file()    
    end      
    
    def check_external_modify
      unless GLib.FileUtils.test(file.location.get_path(), FileTest::EXISTS)
        notify_modify()
        return
      end
    
      file_loader = Gtk.SourceFileLoader.new(@temp_buffer, @file);         
      file_loader.load_async.begin(Priority::DEFAULT, nil, nil) do 
        if temp_buffer.text != saved_buffer.text
          notify_modify()
        end
      end
    end
  end

  class Editor < Gtk::ApplicationWindow
    include Q::KeyBinder
  
    defn [Gtk::Application]
    def initialize(app)
      Object(application: app)
          
      @app_name = "Qode"
      
      self.title = app_name;
      
      set_default_size(800, 600);
      @window_position = Gtk::WindowPosition::CENTER;

      @menu_bar = Gtk::MenuBar.new();
     
      @item_file = Gtk::MenuItem.new_with_mnemonic("_File");
      menu_bar.add(@item_file);

      @item_build = Gtk::MenuItem.new_with_label("Build");
      menu_bar.add(@item_build);

      @file_menu = Gtk::Menu.new();
      item_file.set_submenu(@file_menu);

      @build_menu = Gtk::Menu.new();
      item_build.set_submenu(@build_menu);

      @item_new = Gtk::MenuItem.new_with_mnemonic("_New");
      file_menu.add(item_new);

      @item_open = Gtk::MenuItem.new_with_mnemonic("_Open");
      file_menu.add(item_open);

      @item_save = Gtk::MenuItem.new_with_mnemonic("_Save");
      file_menu.add(item_save);

      @item_compile = Gtk::MenuItem.new_with_mnemonic("_Compile");
      build_menu.add(item_compile);
      
      @item_run = Gtk::MenuItem.new_with_mnemonic("_Run Compile");
      build_menu.add(item_run);      

      @item_close = Gtk::MenuItem.new_with_mnemonic("_Close");
      file_menu.add(item_close);

      @item_quit = Gtk::MenuItem.new_with_mnemonic("_Quit");
      file_menu.add(item_quit);

      accel_group = Gtk::AccelGroup.new();
      add_accel_group(accel_group); 
      
      item_save.add_accelerator("activate", accel_group, `'S'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);
      item_run.add_accelerator("activate", accel_group, `'R'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);
      item_new.add_accelerator("activate", accel_group, `'N'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);
      item_open.add_accelerator("activate", accel_group, `'O'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);
      item_close.add_accelerator("activate", accel_group, `'W'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);

      @paned = Gtk::Paned.new(Gtk::Orientation::VERTICAL)
      @m = Q::DocBook.new()
      
      @m.added.connect() do |d|        
        ev = Document.cast!(d)
        ev.open_file(d.resource) if d.name != nil
        ev.view.populate_popup.connect(on_populate_menu);

        ev.modified.connect() do
          d.name = "* "+d.name
        end

        d.notify['name'].connect() do
          l=Gtk::Notebook.cast!(@m).get_tab_label(d)
          Gtk::Label.cast!(l).label = d.name     
          @m.changed(d) if @m.list[@m.active] == d
        end              
      end
      
      @m.changed.connect() do |d|
        self.title = "Qode | "+d.name   
      end
      
      paned.hexpand = true;
      paned.vexpand = true;

      paned.add1(m)

      @vte = QTe::Terminal.new()
      vte.spawn(["/usr/bin/bash"])
      vte.hexpand = true;
      vte.vexpand = true;
      
      paned.add2(vte)

      paned.size_allocate.connect() do |allocation| 
		if allocation.height != 1
	      pos = 0.71 * allocation.height
  		  paned.set_position(int.cast!(pos + 0.5))
        end
      end
      
      @grid = Gtk::Grid.new();
      @grid.attach(menu_bar,    0, 0, 1, 1);      
      @grid.attach(paned,       0, 1, 1, 1);

      add(@grid);

      show_all();

      connect_signals();
    end

    def connect_signals()
      destroy.connect(application.quit);

      item_open.activate.connect(on_open);
      item_save.activate.connect(on_save);
      item_quit.activate.connect(Gtk.main_quit);
      item_new.activate.connect(on_new);      
      item_close.activate.connect(on_close);  
      
      item_compile.activate.connect() do
        compile()
      end
      
      item_run.activate.connect() do
        run()
      end
      
      connect_keys()
      ctrl_shift_key_press.connect do |k|
        if k==Gdk::Key::D
          @m.cycle()
          next true
        end
        next false
      end
    end

    def on_open()
      chooser = Gtk::FileChooserDialog.new(
          "Select a file to edit", self, Gtk::FileChooserAction::OPEN,
          "_Cancel",
          Gtk::ResponseType::CANCEL,
          "_Open",
          Gtk::ResponseType::ACCEPT);

      chooser.set_select_multiple(false);
      chooser.run();
      chooser.close();

      do_open(chooser.get_file())    
    end  
    
    def on_close
      @m.list[@m.active].close()
    end
    
    def on_new
      d=Document.new
      n="Untitled #{@m.list.length}"
      @m[n] = d
      d.name = n
      d.file = nil
      d.show_all()
      d.activate()
    end

    defn [GLib.File], Document?
    def do_open(f)
      d = @m[f.get_path()] 
      
      if d
        d.activate()
      elsif f
        # TODO: 'file.foo .* file()' triggers `file.foo() .*` 
        d=Document.new()
        d.name = File.basename(f.get_path())
        @m[f.get_path()] = d
      else
        message("Cannot open null file")
        return nil
      end
      
      return Document.cast!(d)    
    end

    def on_save()
      edit = Document.cast!(m.list[m.active])
      edit.save_file()      
    end

    #* Create the submenu to select language for our source view, using the right-click contextual menu
    defn [Gtk::Menu]
    def on_populate_menu(menu)
      edit = Document.cast!(m.list[m.active])
      language_menu = Gtk::MenuItem.new()
      language_menu.set_label("Language")

      submenu = Gtk::Menu.new()
      language_menu.set_submenu(submenu)

      item = Gtk::RadioMenuItem.new(nil);
      item.set_label("Normal Text");
      item.toggled.connect() do
         #//No language, aka normal text edit.
         edit.view.source_buffer.set_language(nil)
      end

      submenu.add(item);

      #// Set the Language entries
      edit.view.language_manager.get_language_ids().each do |id|
        lang = edit.view.language_manager.get_language(id);

        item = Gtk::RadioMenuItem.new(item.get_group());
        item.set_label(lang.name);

        submenu.add(item);
        item.toggled.connect() do
          edit.view.source_buffer.set_language(lang);
        end

        #// Active item
        if ((edit.view.source_buffer.language != null) && (id == edit.view.source_buffer.language.id))
          item.active = true;
        end
      end

      #// Add our Language selection menu to the menu provided in the callback
      menu.add(language_menu);
      menu.show_all();
    end
      
    def compile
      ev = Document.cast!(m.list[m.active])
      on_save()
      t=QTe::Window.new().term
      t.spawn(["/bin/sh"])
      t.feed_child("q #{ev.file.location.get_path()} && ruby -e 'puts :type_enter_to_exit;gets;' && exit\n".data)
    end
    
    def run
      ev = Document.cast!(m.list[m.active])
      on_save()
      t=QTe::Window.new().term
      t.spawn(["/bin/sh"])
      t.feed_child("q #{ev.file.location.get_path()} -r && ruby -e 'puts :type_enter_to_exit;gets;' && exit\n".data)
    end
    
    property(:active, Qode.Document) {
      def get; return Qode.Document.cast!(@m.list[@m.active]) end
    }

    property(:view, Qode.EditView) {
      def get; return @active.view end
    }
  end
  
  class QodeEditor < Q.Application
    def initialize
      super("q.qode.application")
	  
      @session = "./qode.session"	  
	  
      open_file.connect() do |file|
        Editor.cast!(@window).do_open(file);
      end
    
      create_window.connect() do
        next @editor=Editor.new(self)
      end
      
      handle_options.connect do |opts,cl|
        if vs=opts.get("search")
          search = string.cast!(vs)
          if rv=opts.get("replace-all")
            @editor.view.replace_all(search, string.cast!(rv))
          end

          if sv=opts.get("session-replace-all")
            @editor.m.list.each do |e|
              Document.cast!(e).view.replace_all(search, string.cast!(sv))
            end
          end
          
          if opts["find-all"]
            @editor.m.list.each do |e|
              text = Document.cast!(e).view.buffer.text
              i    = -1
              
              text.split("\n").each do |l|
                i+=1
                
                if l =~ /#{search}/
                  cl.print "File: #{e.resource}:#{i} - #{l}\n"
                end
              end
            end
          end          
        end
      
        if v=opts.get("session")
          @session = string.cast!(v)
        end
                
        if v2=opts.get("activate")
          GLib::Idle.add do
            next false if !@editor
            
            a = string.cast!(v2)
            
            if @editor.m[a]
              @editor.m[a].activate()
            end
            
            next false            
          end
        end        
        
        if v=opts["goto"]
          GLib::Idle.add do
            @editor.view.go_to(0,int.cast!(v)) if @editor
            
            next false
          end
        end        
        
        if opts["list"]
          next 1 if (nil==@window)
          
          editor.m.list.each do |doc|
            cl.print doc.resource+"\n"
          end 
          
          next 0
        end
        
        if opts["current"]
          next 1 if (nil==@window)
          
          d=editor.active
          cl.print d.resource+"\n"
           
          next 0
        end        
        
        restore() if (nil==@window) && cl.get_arguments().length == 1
        next 0
      end
      
      add_option("list",    `'l'`, OptionFlags.NONE, OptionArg.NONE,   "list session files",                       nil)
      add_option("current", `'c'`, OptionFlags.NONE, OptionArg.NONE,   "print current document path",              nil)
      add_option("activate",`'a'`, OptionFlags.NONE, OptionArg.STRING, "set document PATH as current document",    "PATH")
      add_option("goto",    `'g'`, OptionFlags.NONE, OptionArg.INT,    "goto line LINE",                           "LINE")      
      add_option("session", `'s'`, OptionFlags.NONE, OptionArg.STRING, "load session SESSION",                     "SESSION") 
      add_option("search",  `'f'`, OptionFlags.NONE, OptionArg.STRING,             "set search to SEARCH",                    "SEARCH") 
      add_option("replace-all", `'R'`, OptionFlags.NONE, OptionArg.STRING,         "replace all SEARCH with TEXT",            "TEXT") 
      add_option("session-replace-all", `'Q'`, OptionFlags.NONE, OptionArg.STRING, "replace all SEARCH in session with TEXT", "TEXT")             
      add_option("find-all",  `'F'`, OptionFlags.NONE, OptionArg.NONE,             "find-all SEARCH in session",               nil)      
    end
     
    def restore()    
      activate()
        
      if GLib.FileUtils.test(@session, FileTest.EXISTS)
        fa = File.read(@session).split("\n")

        fa.each do |l|
          open_file(File.new_for_path(l)) if l!=""
        end
      end
    end
  end 
end

if __FILE__ == $0
  app = Qode::QodeEditor.new();
  app.run(q_args);
end
