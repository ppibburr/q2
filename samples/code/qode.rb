require pkg: 'gtk+-3.0'
require pkg: 'gtksourceview-3.0'

require 'documents/doc.rb'
require 'qte/qte.rb'
require 'code/edit.rb'

namespace module Qode
 class Document < Gtk::ScrolledWindow
    include Documents::Doc
    attr_accessor(:name) {:string?}
    attr_accessor(:resource) {:string?}
    attr_reader(:view) {:EditView}
    
    def initialize
      set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC);
      @_view = EditView.new()
      add(view);    
    end
       
    def open_file(f)
      @file = Gtk::SourceFile.new()
      @file.location = `File.new_for_path(f)`

      view.source_buffer.set_language(view.language_manager.guess_language(@resource,nil))       

      file_loader = Gtk.SourceFileLoader.new(view.source_buffer, file);         
      file_loader.load_async.begin(Priority::DEFAULT, nil, nil);
      show_all()
    end
  end
  
  class Editor < Gtk.Window
    defn [:string?]
    def initialize(f)
      @app_name = "Qode"
      
      @title = app_name;
      
      set_default_size(800, 600);
      @window_position = Gtk::WindowPosition::CENTER;

      @menu_bar = Gtk::MenuBar.new();
     
      @item_file = Gtk::MenuItem.new_with_mnemonic("_File");
      menu_bar.add(@item_file);

      @item_build = Gtk::MenuItem.new_with_label("Build");
      menu_bar.add(@item_build);

      @file_menu = Gtk.Menu.new();
      item_file.set_submenu(@file_menu);

      @build_menu = Gtk.Menu.new();
      item_build.set_submenu(@build_menu);

      @item_open = Gtk.MenuItem.new_with_label("Open");
      file_menu.add(item_open);

      @item_save = Gtk.MenuItem.new_with_mnemonic("_Save");
      file_menu.add(item_save);

      @item_compile = Gtk.MenuItem.new_with_mnemonic("_Compile");
      build_menu.add(item_compile);
      
      @item_run = Gtk.MenuItem.new_with_mnemonic("_Run Compile");
      build_menu.add(item_run);      

      @item_quit = Gtk.MenuItem.new_with_mnemonic("_Quit");
      file_menu.add(item_quit);

      accel_group = Gtk::AccelGroup.new();
      add_accel_group(accel_group); 
      
      item_save.add_accelerator("activate", accel_group, `'S'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);
      item_run.add_accelerator("activate", accel_group, `'R'`, Gdk::ModifierType::CONTROL_MASK, Gtk::AccelFlags::VISIBLE);

      @paned = Gtk::Paned.new(Gtk::Orientation::VERTICAL)
      @m = Documents::MyMGR.new()
      
      @m.added.connect() do |d|
        p "Added: #{d.name}"
        
        ev = Document.cast!(d)
        ev.open_file(d.resource)
        ev.view.populate_popup.connect(on_populate_menu);
        @title = "#{app_name} | #{ev.file.location.get_path()}"
        vte.feed_child("cd #{File.dirname(ev.file.location.get_path())}\n".data)        
      end
      
      @m.changed.connect() do |d|
        @title = d.name
      end
      
      paned.hexpand = true;
      paned.vexpand = true;

      paned.add1(m)

      @vte = QTe::Terminal.new()
      vte.spawn(["/usr/bin/bash"])
      vte.hexpand = true;
      vte.vexpand = true;
      
      paned.add2(vte)

      grid = Gtk::Grid.new();
      grid.attach(menu_bar, 0, 0, 1, 1);
      grid.attach(paned, 0, 1, 1, 1);

      add(grid);

      show_all();

      connect_signals();
      
      if f != nil
        do_open(File.new_for_path(f))
      end
    end

    def connect_signals()
      destroy.connect(Gtk.main_quit);

      # * Set the callbacks for the items in the File Menu
      item_open.activate.connect(on_open);
      item_save.activate.connect(on_save);
      item_quit.activate.connect(Gtk.main_quit);
      
      item_run.activate.connect() do
        run()
      end

      # *Populate the contextual menu after the right click. We need to select a language for our sourceview.
    end

    # * We will select a file using FileChooser and load it to the editor.
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
    
    def do_open(f)
      if f != nil
       # TODO: 'file.foo .* file()' triggers `file.foo() .*` 
        d=Document.new()
        d.name = File.basename(f.get_path())
        @m[f.get_path()] = d
        
      end    
    end

    # *This will save the file to the location we had defined before.
    # *It doesn't consider the case where you didn't "select" a file before.
    def on_save()
      edit = Document.cast!(m.list[m.active])
      file = edit.file
      if (file != nil && !file.is_readonly())
        file_saver = Gtk.SourceFileSaver.new(edit.view.source_buffer, file);
        file_saver.save_async.begin(Priority::DEFAULT, nil, nil);
      end
    end

    #* Create the submenu to select language for our source view, using the right-click contextual menu
    defn [Gtk::Menu]
    def on_populate_menu(menu)
      edit = Document.cast!(m.list[m.active])
      language_menu = Gtk::MenuItem.new()
      language_menu.set_label("Language")

      submenu = Gtk::Menu.new()
      language_menu.set_submenu(submenu)

      #//Add an entry with No Language, or normal.
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
  end
end

Gtk.init(ref Q_ARGV);

my_editor = Qode::Editor.new(ARGV[0]);
my_editor.show_all();

Gtk.main();
