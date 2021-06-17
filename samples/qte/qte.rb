require pkg: "vte-2.91"
require pkg: "gtk+-3.0"

namespace module QTe
  class App
    defn ['string[]']
    def initialize argv
      Gtk.init(ref argv)      
      Window.new().term.child_exited.connect() do Gtk.main_quit() end  
      Gtk.main()
    end
  end
  
  class Window < Gtk::Window
    def initialize
      #//create the new terminal
      @term = QTe::Terminal.new()
      term.spawn(["/usr/bin/bash"])
      term.child_exited.connect() do destroy() end
      add(term);
      show_all() 
    end  
  end
  
  class Terminal < Vte::Terminal
    defn [:string[]]
    def spawn(a)
      pid = :Pid?.nil!
      spawn_sync(Vte::PtyFlags::DEFAULT,nil,a,Environ.get(), SpawnFlags::DO_NOT_REAP_CHILD,nil,out(pid),nil)
      return pid
    end
  end
end
