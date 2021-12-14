require pkg: "webkit2gtk-4.0"
require pkg: "JavaScriptCore-4.0"

Gtk.init(ref Q.args)

u = "http://google.com"

v = WebKit::WebView.new()
v.load_uri(u)
v.load_changed.connect() do |e|
  if e == WebKit::LoadEvent::COMMITTED
    v.run_javascript.begin('function plugin_init() {return "Q";};plugin_init();', nil)  do |o,r|
      p v.run_javascript.end(r).get_js_value()
    end
  end
end  
w = Gtk::Window.new()
w.add(v)

w.show_all()
w.resize(800,600)

w.destroy.connect(Gtk.main_quit)
Gtk.main()
