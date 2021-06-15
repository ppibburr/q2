require pkg: 'gtk+-3.0'
require pkg: 'gtksourceview-3.0'

require 'qte/qte.rb'

namespace module Qode
  class Editor < Gtk.Window
    defn [:string?]
    def initialize(f)
      @app_name = "Qode"
      
      @title = app_name;
      
      set_default_size(800, 600);
      @window_position = Gtk::WindowPosition::CENTER;

      @menu_bar = Gtk::MenuBar.new();
     
      @item_file = Gtk::MenuItem.new_with_label("File");
      menu_bar.add(@item_file);

      @file_menu = Gtk.Menu.new();
      item_file.set_submenu(@file_menu);

      @item_open = Gtk.MenuItem.new_with_label("Open");
      file_menu.add(item_open);

      @item_save = Gtk.MenuItem.new_with_label("Save");
      file_menu.add(item_save);

      @item_compile = Gtk.MenuItem.new_with_label("compile");
      file_menu.add(item_compile);
      
      @item_run = Gtk.MenuItem.new_with_label("Run Compile");
      file_menu.add(item_run);      

      @item_quit = Gtk.MenuItem.new_with_label("Quit");
      file_menu.add(item_quit);

      @source_view = Gtk::SourceView.new();
      source_view.set_wrap_mode(Gtk::WrapMode::WORD);
      source_view.buffer.text = "";
     
      source_view.show_line_numbers = true
      source_view.show_line_marks   = true
      source_view.insert_spaces_instead_of_tabs = true
      source_view.indent_width = 2
      source_view.highlight_current_line = true
      source_view.auto_indent = true
     
      @language_manager = Gtk::SourceLanguageManager.get_default();


      @paned = Gtk::Paned.new(Gtk::Orientation::VERTICAL)

      scrolled_window = Gtk::ScrolledWindow.new(nil, nil);
      scrolled_window.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC);
      scrolled_window.add(source_view);
      paned.hexpand = true;
      paned.vexpand = true;

      paned.add1(scrolled_window)

      @vte = QTe::Terminal.new()
      vte.spawn(["/usr/bin/bash"])
      vte.hexpand = true;
      vte.vexpand = true;
      
      paned.add2(vte)

      grid = Gtk::Grid.new();
      grid.attach(menu_bar, 0, 0, 1, 1);
      grid.attach(paned, 0, 1, 1, 1);

      add(`grid as Gtk.Widget`);

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
      source_view.populate_popup.connect(on_populate_menu);
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
        @file = Gtk::SourceFile.new()
       # TODO: 'file.foo .* file()' triggers `file.foo() .*` 
        @file.location = f;

        @title = "#{app_name} | #{file.location.get_path()}"

        file_loader = Gtk.SourceFileLoader.new(`source_view.buffer as Gtk.SourceBuffer`, file);         
        file_loader.load_async.begin(Priority::DEFAULT, nil, nil);
        `(source_view.buffer as Gtk.SourceBuffer).set_language(language_manager.guess_language(file.location.get_path(),null));`
        vte.feed_child("cd #{File.dirname(file.location.get_path())}\n".data)
      end    
    end

    # *This will save the file to the location we had defined before.
    # *It doesn't consider the case where you didn't "select" a file before.
    def on_save()
      if (file != nil && !file.is_readonly())
        file_saver = Gtk.SourceFileSaver.new(`source_view.buffer as Gtk.SourceBuffer`, file);
        file_saver.save_async.begin(Priority::DEFAULT, nil, nil);
      end
    end

    #* Create the submenu to select language for our source view, using the right-click contextual menu
    defn [Gtk::Menu]
    def on_populate_menu(menu)
      language_menu = Gtk::MenuItem.new()
      language_menu.set_label("Language")

      submenu = Gtk::Menu.new()
      language_menu.set_submenu(submenu)

      #//Add an entry with No Language, or normal.
      item = Gtk::RadioMenuItem.new(nil);
      item.set_label("Normal Text");
      item.toggled.connect() do
         #//No language, aka normal text edit.
         `(source_view.buffer as Gtk.SourceBuffer).set_language (null);`
      end

      submenu.add(item);

      #// Set the Language entries
      language_manager.get_language_ids().each do |id|
        lang = language_manager.get_language(id);

        item = Gtk::RadioMenuItem.new(item.get_group());
        item.set_label(lang.name);

        submenu.add(item);
        item.toggled.connect() do
          `(source_view.buffer as Gtk.SourceBuffer).set_language(lang);`
        end

        #// Active item
        if (`(source_view.buffer as Gtk.SourceBuffer).language != null` && `id == (source_view.buffer as Gtk.SourceBuffer).language.id`)
          item.active = true;
        end
      end

      #// Add our Language selection menu to the menu provided in the callback
      menu.add(language_menu);
      menu.show_all();
    end
  
    def system c
      stdout = :string.nil!;
      stderr = :string.nil!;
      status = :int?.nil!;

    
      Process.spawn_command_line_sync(c,
                                    out(stdout),
                                    out(stderr),
                                    out(status));
      puts stdout
      puts "exited: #{status}"    
    end
    
    def compile
      system "q #{file.location.get_path()} &"
    end
    
    def run
      compile()
      system "./#{file.location.get_basename().split(".")[0]}"
    end
  end
end

Gtk.init(ref Q_ARGV);

my_editor = Qode::Editor.new(ARGV[0]);
my_editor.show_all();

Gtk.main();
