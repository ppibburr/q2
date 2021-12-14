require pkg: 'gtk+-3.0'
require pkg: 'gtk-vnc-2.0'
require pkg: 'webkit2gtk-4.0'

require q: 'samples/documents/doc.rb'
require q: 'samples/application.rb'
require q: 'samples/keys.rb'

namespace 
module QVnc
  module RemoteView
    include Gtk::Widget
    include Q::Doc  

    signal() {
      def reconnect; end
      def disconnect; end      
    }
    
    attr_accessor(:scaling) {bool}
  end

  class VncView < Gtk::ScrolledWindow
    include Q::Doc      
    include RemoteView

    attr_accessor(:name) {:string?}
    attr_accessor(:resource) {:string?}
    
    property(:scaling, bool) {
      def get; return @vnc.scaling; end
      def set; @vnc.scaling = value; end
    }
    
    def initialize
      add @vnc = Vnc::Display.new()

      left.connect() do
        p "left: #{@name}"
        @vnc.close()
      end
     
     closed.connect() do
       p "closed: #{name}"
       @vnc.close()
       destroy()
     end
     
      activated.connect() do
        reconnect()   
      end
      
      reconnect.connect do
        p "connect: #{@name}"
        a = resource.split(":")

        @vnc.open_host a[0],a[1]
        @vnc.set_force_size false
        @vnc.scaling = true        
      end
    end
  end

  class VncStack < Q::DocumentStack      
    attr_reader(:listbox) {Q::DocumentListSwitcher}
    
    def initialize
      @_listbox = Q::DocumentListSwitcher.new(self)
            
      changed.connect() do |d|
        view = RemoteView.cast!(d)
        p "Stack Changed: #{d.name}"
        view.show_all()
      end  
    end
    
    def active_view
      return RemoteView.cast!(base.active_document())
    end
  end
  
  class VncSidebar < Gtk::Box
    attr_reader(:list) {Q::DocumentListSwitcher}
    attr_reader(:fs) {:bool}
    def initialize list 
      self.orientation = Gtk::Orientation::VERTICAL
      @_fs = false
      pack_start tb=Gtk::Toolbar.new(), false, false, 1
      tb.add f=Gtk::ToolButton.new_from_stock(Gtk::Stock::FULLSCREEN)
      tb.add n=Gtk::ToolButton.new_from_stock(Gtk::Stock::ZOOM_100)
      #tb.add s=Gtk::ToolButton.new(stock_id: Gtk::Stock::ZOOM_FIT)
      
      f.clicked.connect() do 
        w=QVnc::VncWindow.cast!(Gtk::Application.cast!(GLib::Application.get_default()).active_window)
       
        if !_fs
          @_fs = true
          w.fullscreen()
        else
          @_fs=false
          w.unfullscreen()
        end
      end

      n.clicked.connect() do 
        RemoteView.cast!(list.mgr.active_document()).scaling = !RemoteView.cast!(list.mgr.active_document()).scaling
      end
      
      tb.add r=Gtk::ToolButton.new_from_stock(Gtk::Stock::REFRESH)
      r.clicked.connect() do
        RemoteView.cast!(list.mgr.active_document()).reconnect()
      end
            
      pack_start sw=Gtk::ScrolledWindow.new(nil,nil),true, true, 1
      sw.add @_list=list
    end
  end
  
  class VncWindow < Gtk::ApplicationWindow
    `public static VncWindow main;`

    attr_reader(:stack) {VncStack}
    attr_reader(:sidebar) {VncSidebar}
    
    defn [Q::Application]
    def initialize app
      Object(application: app)
      add h=Gtk::Paned.new(Gtk::Orientation::HORIZONTAL)
      
      #@main = self     
      ref()
      h.add2 @_stack   = VncStack.new()
      h.add1 @_sidebar = VncSidebar.new(@stack.listbox)
            
      do_title("HanleyVNC")    
      
      h.position=230
      resize 1200,800
      show_all()
      
      delete_event.connect() do
        app.quit()
        next false
      end
      
      stack.changed.connect() do |d|
        p "Title: #{d.name}"
        do_title d.name        
      end
    end
    
    def do_title n
      self.title = ("HanleyVNC | #{n}")    
    end
  end
  
  class VncApp < Q::Application
    defn [string]
    def initialize name
      if name
     
      elsif !name
        name = "org.q.vnc"
      end
    
      super name
     
      add_options()
      
      handle_options.connect() do |opts,cl|
        next do_handle_options(opts,cl)
      end
    end
    
  
    def add_options
      add_main_option("host", `'h'`, GLib::OptionFlags::NONE, OptionArg.STRING, "host to connect", "HOST_NAME")
      add_main_option("port", `'p'`, GLib::OptionFlags::NONE, OptionArg.STRING, "port to use", "PORT")
      add_main_option("name", `'n'`, GLib::OptionFlags::NONE, OptionArg.STRING, "display name", "NAME")   
    end  
   

    def do_handle_options opts,cl
      if h=opts.get("host")
        host = string.cast!(h)
        port = "5900"
        if h=opts.get("port")
          port = string.cast!(h)
        end
        res = "#{host}:#{port}"
        n = res
        if h=opts.get("name")
          n = string.cast!(h)
        end

        activate()

        d = QVnc::VncView.new()
        d.name = n
        QVnc::VncWindow.cast!(@window).stack[res] = d

        return -1
      end
     
      return 0
    end
  end
    
  class WebsiteDataManager < WebKit::WebsiteDataManager
    defn [string]
    def initialize(base_cache_directory)
      Object(
          base_cache_directory: base_cache_directory,
          base_data_directory: base_cache_directory
      );
    end
  end

  class Web < Gtk::ScrolledWindow
    include Q::Doc
    include QVnc::RemoteView
    
    attr_accessor(:scaling) {bool}
    attr_accessor(:name) {string?}
    attr_accessor(:resource) {string?}
      
    def initialize
      @_web_context = WebKit::WebContext.new_with_website_data_manager(WebsiteDataManager.new(GLib::Environment.get_user_cache_dir()+"/#{GLib::Environment.get_prgname()}"))
      cf = @_web_context.website_data_manager.base_cache_directory+"/cookies.txt"
      @_web_context.get_cookie_manager().set_persistent_storage(cf, WebKit::CookiePersistentStorage::TEXT)
      
      add_with_viewport @webview = WebKit::WebView.new_with_context(@_web_context)
      
        _web_settings = @webview.get_settings()

        _web_settings.enable_developer_extras = true
        _web_settings.enable_webgl = true
        _web_settings.enable_plugins = true
        _web_settings.user_agent = "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:64.0) Gecko/20100101 Firefox/64.0"
            
      
      reconnect.connect() do
        @webview.load_uri(@resource)
      end
    end
  end


  class HanleyVnc < VncApp
    def initialize
      super('org.q.vnc')

      @rdoc = 5

      create_window.connect() do  
        w = QVnc::VncWindow.new(self)

        web = Web.new()
        web.name = 'Faults'
        w.stack["http://192.1.168.211:4567"] = web

        web = Web.new()
        web.name = 'Downtime'
        w.stack["http://192.1.168.211:4568/packaging"] = web

        web = Web.new()
        web.name = 'Crusher'
        w.stack["http://192.168.1.113"] = web

        d = QVnc::VncView.new()
        d.name = 'Kiln'
        w.stack["192.1.168.32:5920"] = d

        d = QVnc::VncView.new()
        d.name = 'self'
        w.stack["0.0.0.0:5910"] = d

        d = QVnc::VncView.new()
        d.name = 'maint-desk'
        w.stack["192.1.168.211:5900"] = d

        d = QVnc::VncView.new()
        d.name = 'scrubber'
        w.stack["192.1.168.69:5900"] = d

        d = QVnc::VncView.new()
        d.name = 'alar1'
        w.stack["192.168.0.2:5900"] = d

        d = QVnc::VncView.new()
        d.name = 'TR3'
        w.stack["192.168.1.73:5900"] = d

        w.resize(1280, 780)
        
        next w
      end
    end
    
    def get_active
      return QVnc::VncWindow.cast!(@window)
    end
    
    def add_options()
      override!
      
      base.add_options()
 
      add_main_option("close",    `'c'`, GLib::OptionFlags::NONE, OptionArg.STRING, "close NAME", "NAME")  
      add_main_option("activate", `'a'`, GLib::OptionFlags::NONE, OptionArg.STRING, "activate RESOURCE", "RESOURCE")   
      add_main_option("list",     `'l'`, GLib::OptionFlags::NONE, OptionArg.NONE, "list remotes", nil)    
    end
    
    defn [Q::Options, ApplicationCommandLine], int
    def do_handle_options(opts,cl)
      override!
      ec = base.do_handle_options(opts,cl)
      if ec < 1
       
        if r=opts.get("close")
          doc=get_active().stack.get(string.cast!(r))
          QVnc::VncWindow.cast!(@window).stack.remove(doc) if doc 
          doc.close() if doc
        end

        if opts["list"]
          GLib::Idle.add do
            QVnc::VncWindow.cast!(@window).stack.list.each do |doc| 
              cl.print "#{doc.resource} #{doc.name}\n" 
            end
            next false
          end
        end  
        
        if r=opts.get("activate")
          GLib::Idle.add do
            QVnc::VncWindow.cast!(@window).stack[string.cast!(r)].activate()
            next false
          end
        end        
        
        return ec
      else
        return ec
      end
    end
  end
end

if __FILE__ == $0
  app = QVnc::HanleyVnc.new()
  app.run(Q.args) 
end
