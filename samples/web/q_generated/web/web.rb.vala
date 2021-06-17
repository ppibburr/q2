// File: /home/ppibburr/git/q2/samples/web/web.rb



// #;
public class ValaBrowser : Gtk.Window {
  // Fields set to infered type via @<var> assignment!;
  public string default_protto;
  public string default_uri;
  public Regex protocol_regex;
  public Gtk.ToolButton back_button;
  public Gtk.ToolButton forward_button;
  public Gtk.ToolButton reload_button;
  public Gtk.Entry url_bar;
  public WebKit.WebView web_view;
  public Gtk.Label status_bar;
  // END infered @<var>;

  
  
  public  ValaBrowser() {
  
    ///home/ppibburr/git/q2/samples/web/web.rb: 6;
    this.default_protto = "http";
    this.default_uri = "http://google.com";
    this.title = "QWeb";
    set_default_size(800, 600);
    this.protocol_regex = /.*:\/\/.*/;
    create_widgets();
    connect_signals();
    url_bar.grab_focus();
  }
  
  
  
  public void create_widgets() {
    Gtk.Toolbar toolbar;  Gtk.Image img;  Gtk.ScrolledWindow scrolled_window;  Gtk.Box box;
    ///home/ppibburr/git/q2/samples/web/web.rb: 20;
    toolbar = new Gtk.Toolbar();
    img = new Gtk.Image.from_icon_name("go-previous", Gtk.IconSize.SMALL_TOOLBAR);
    this.back_button = new Gtk.ToolButton(img, null);
    img = new Gtk.Image.from_icon_name("go-next", Gtk.IconSize.SMALL_TOOLBAR);
    this.forward_button = new Gtk.ToolButton(img, null);
    img = new Gtk.Image.from_icon_name("view-refresh", Gtk.IconSize.SMALL_TOOLBAR);
    this.reload_button = new Gtk.ToolButton(img, null);
    toolbar.add(back_button);
    toolbar.add(forward_button);
    toolbar.add(reload_button);
    this.url_bar = new Gtk.Entry();
    this.web_view = new WebKit.WebView();
    scrolled_window = new Gtk.ScrolledWindow(null, null);
    scrolled_window.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
    scrolled_window.add(web_view);
    this.status_bar = new Gtk.Label("Welcome");
    status_bar.xalign = 0;
    box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
    box.pack_start(toolbar, false, true, 0);
    box.pack_start(url_bar, false, true, 0);
    box.pack_start(scrolled_window, true, true, 0);
    box.pack_start(status_bar, false, true, 0);
    add(box);
  }
  
  
  
  public void connect_signals() {
  
    ///home/ppibburr/git/q2/samples/web/web.rb: 55;
    destroy.connect(Gtk.main_quit);
    url_bar.activate.connect(on_activate);
    web_view.load_changed.connect( ( source, evt) => {
       url_bar.text = source.get_uri();
      update_buttons(); 
    });
    web_view.notify["title"].connect( () => {
       this.title = "%s - %s".printf(web_view.title, "QWeb"); 
    });
    back_button.clicked.connect(web_view.go_back);
    forward_button.clicked.connect(web_view.go_forward);
    reload_button.clicked.connect(web_view.reload);
  }
  
  
  
  public void update_buttons() {
  
    ///home/ppibburr/git/q2/samples/web/web.rb: 74;
    this.back_button.sensitive = this.web_view.can_go_back();
    this.forward_button.sensitive = this.web_view.can_go_forward();
  }
  
  
  
  public void on_activate() {
    MatchInfo _q_match_data;
    ///home/ppibburr/git/q2/samples/web/web.rb: 79;
    var url = this.url_bar.text;
    if (!(this.protocol_regex.match(url, 0, out _q_match_data))) {
      url = "%s://%s".printf(default_protto, url);
    }
    this.web_view.load_uri(url);
  }
  
  
  
  public void start() {
  
    ///home/ppibburr/git/q2/samples/web/web.rb: 87;
    show_all();
    web_view.load_uri(default_uri);
  }
  
  
  
  
  public static int main(string[] args) {
    ValaBrowser browser;
    ///home/ppibburr/git/q2/samples/web/web.rb: 93;
    Gtk.init(ref(args));
    browser = new ValaBrowser();
    browser.start();
    Gtk.main();
    return 0;
  }
}
