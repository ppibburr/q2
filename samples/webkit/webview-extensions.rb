require pkg: "webkit2gtk-4.0"

Gtk.init(ref Q.args)

c=WebKit::WebContext.get_default()
c.set_web_extensions_directory("./")
c.set_web_extensions_initialization_user_data(Variant.new_string("\"foo\": 1"))
v = WebKit::WebView.new()
v.load_html("<form><input name=username type=text></input><br><input type='password' name=password></input>","")
w = Gtk::Window.new()
w.add(v)

w.show_all()
w.resize(800,600)

w.destroy.connect(Gtk.main_quit)
Gtk.main()

