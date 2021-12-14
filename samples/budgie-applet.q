require pkg: "budgie-1.0"
require pkg: "ruby"

namespace 
module Q
  class AppletPlugin < Peas::ExtensionBase
    include Budgie::Plugin
    
    `public static Type? plugin = null;`
    
    defn [string], Budgie::Applet
    override!
    def get_panel_widget(uuid)
      n    = "uuid"
      pi   = "plugin_info"
      plug = GLib::Value?.nil!
      plug = plugin_info
      v    = GLib::Value?.nil!
      v    = uuid
      
      applet = Q::Applet.cast!(`Object.new_with_properties(plugin, {n,pi}, {v,plug})`)
      applet.init()
      applet.ready(applet)
      applet.show_all()
      
      return Budgie::Applet.cast!(applet)
    end
  end

  class AppletPopover < Budgie::Popover
    defn [Gtk::Widget]
    def initialize box
      GLib::Object(relative_to: box);
    end
  end
  
  # The actual applet implementation. It's basically a GtkBin
  class Applet < Budgie.Applet
    defn [string]
    attr_accessor(:uuid) {string?}
    attr_accessor(:plugin_info) {Peas::PluginInfo?}
    attr_accessor(:has_settings_widget) {bool}
    
    defn [string?]
    def initialize(uuid = nil)
      @uuid = uuid
      ## How to use relocatable schemas:
      # Object(settings_prefix = "/com/myawesome/applet/instance/awesome",
      #        settings_schema = "com.myawesome.applet");
      # settings = get_applet_settings(uuid)
      Object(uuid: uuid);
      
      @manager = Budgie::PopoverManager?.nil!
    end

    def init; 
      @_init=true
    end

    ## * Let the panel manager know we support a settings UI
    override!
    def supports_settings()
      return @has_settings_widget
    end

    ## this is destroyed each time the user navigates away from the view.
    override!
    defn [Gtk::Widget], Gtk::Widget?
    def get_settings_ui()
      return settings_widget()
    end

    signal() {
      defn [Budgie::PopoverManager]
      def manage_popovers(manager); end
      defn [Q::Applet]
      def ready(applet);end
      defn [], Gtk::Widget
      def settings_widget(); end
    }
    
    defn [Gtk::Widget], Q::AppletPopover
    def make_popover(parent)
      popover = Q::AppletPopover.new(parent)
      setup_popover(parent, popover)
      return popover
    end
    
    def setup_popover parent,popover  
      parent.button_press_event.connect() do |e|
        # Not primary button? Good bye! */
        if (e.button != 1)
          next Gdk::EVENT_PROPAGATE;
        end
        
        if (popover.get_visible() == true)
          popover.hide();
        else
          manager.show_popover(parent);
        end
        
        next Gdk::EVENT_STOP;
      end
    end
    
    ## * When using popovers, always register them in the entry method
    defn [Budgie::PopoverManager?]
    override!
    def update_popovers(manager)
      @manager = manager;
      manage_popovers(manager)
    end  
    
    defn [Gtk::Widget, Q::AppletPopover]
    def register_popover(parent, popover)
      @manager.register_popover(parent, popover)
    end
  
    defn [TypeModule, Type]
    def self.register _module, applet_class
      Q::AppletPlugin.plugin = applet_class
      Peas::ObjectModule.cast!( _module).
      register_extension_type(typeof(Budgie::Plugin),
                              typeof(Q.AppletPlugin));  
    end    
  end

  class AppletSettings < Gtk.Box
  end 
end
