require pkg: 'gtk+-3.0'

namespace
module Q
  module KeyBinder
    include Gtk::Widget

    def connect_keys
      key_press_event.connect() do |e|
        if ((e.key.state & Gtk.accelerator_get_default_mod_mask()) == (Gdk::ModifierType::CONTROL_MASK | Gdk::ModifierType::SHIFT_MASK))
          next ctrl_shift_key_press(e.keyval)
        end
        
        if ((e.key.state & Gtk.accelerator_get_default_mod_mask()) == (Gdk::ModifierType::CONTROL_MASK))
          next ctrl_key_press(e.keyval)
        end
        
        next key_press(e.keyval)
      end    
    end
  
    signal() {
      defn [:uint], :bool
      def key_press(k); end
      defn [:uint], :bool
      def ctrl_key_press(k); end
      defn [:uint], :bool
      def ctrl_shift_key_press(k); end
    }       
  end
end

if __FILE__ == $0

class Window < Gtk::Window
  include Q::KeyBinder
  def initialize
    connect_keys()
    
    ctrl_shift_key_press.connect() do |k|
      p "key: Ctrl+Shift+#{Gdk.keyval_name(k)}"
      next true
    end
    
    ctrl_key_press.connect() do |k|
      p "key: Ctrl+#{Gdk.keyval_name(k)}"
      next true
    end
    
    key_press.connect() do |k|
      p "key: #{Gdk.keyval_name(k)}"
      next true
    end        
    
    show_all()
  end
end
Gtk.init(ref Q.args)
Window.new
Gtk.main()
end

