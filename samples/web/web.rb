require pkg: 'gtk+-3.0'
require pkg: 'webkit2gtk-4.0'

#
class ValaBrowser < Gtk::Window
    def initialize()
        @default_protto = "http"
        @default_uri   = "http://google.com"
    
        @title = "QWeb";
        set_default_size(800, 600);

        @protocol_regex = /.*:\/\/.*/

        create_widgets();
        connect_signals();
        url_bar.grab_focus();
    end

    def create_widgets()
        toolbar = Gtk::Toolbar.new();
       
        img = Gtk::Image.new_from_icon_name("go-previous", Gtk::IconSize::SMALL_TOOLBAR);
        @back_button = Gtk::ToolButton.new(img, nil);
       
        img = Gtk.Image.new_from_icon_name("go-next", Gtk::IconSize::SMALL_TOOLBAR);
        @forward_button = Gtk::ToolButton.new(img, nil);
       
        img = Gtk.Image.new_from_icon_name("view-refresh", Gtk::IconSize::SMALL_TOOLBAR);
        @reload_button = Gtk::ToolButton.new(img, nil);
       
       toolbar.add(back_button);
        toolbar.add(forward_button);
        toolbar.add(reload_button);
      
        @url_bar = Gtk::Entry.new();
        @web_view = WebKit::WebView.new();
      
        scrolled_window = Gtk::ScrolledWindow.new(nil, nil);
        scrolled_window.set_policy(Gtk::PolicyType::AUTOMATIC, Gtk::PolicyType::AUTOMATIC);
        scrolled_window.add(web_view);
      
        @status_bar = Gtk::Label.new("Welcome");
        status_bar.xalign = 0;
     
        box = Gtk::Box.new(Gtk::Orientation::VERTICAL, 0);
        box.pack_start(toolbar, false, true, 0);
        box.pack_start(url_bar, false, true, 0);
        box.pack_start(scrolled_window, true, true, 0);
        box.pack_start(status_bar, false, true, 0);
      
        add(box);
    end

    def connect_signals()
        destroy.connect(Gtk.main_quit);
        url_bar.activate.connect(on_activate);
      
        web_view.load_changed.connect() do |source, evt|
            url_bar.text = source.get_uri();
           
            update_buttons();
        end
        
        web_view.notify['title'].connect() do
          @title = "%s - %s".printf(web_view.title, "QWeb");
        end
      
        back_button.clicked.connect(web_view.go_back);
        forward_button.clicked.connect(web_view.go_forward);
        reload_button.clicked.connect(web_view.reload);
    end

    def update_buttons()
        @back_button.sensitive = @web_view.can_go_back();
        @forward_button.sensitive = @web_view.can_go_forward();
    end

    def on_activate()
        url = @url_bar.text;
        if !(url =~ this.protocol_regex)
          url = "%s://%s".printf(default_protto, url);
        end
        @web_view.load_uri(url);
    end

    def start()
        show_all();
        web_view.load_uri(default_uri);
    end

    defn [:string[]],:int
    def self.main(args)
        Gtk.init(ref args);

        browser = ValaBrowser.new();
        browser.start();

        Gtk.main();

        return 0;
    end
end
