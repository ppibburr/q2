require pkg: "vte-2.91"
require pkg: "gtk+-3.0"

namespace module QTe
  class App
    defn ['string[]']
    def initialize argv
        Gtk.init(ref argv)      
        pid = :Pid?.nil!
        @w = Gtk::Window.new(Gtk::WindowType::TOPLEVEL);
        #//create the new terminal
        @term = QTe::Terminal.new()
        term.child_exited.connect() do Gtk.main_quit() end
        term.spawn(["/usr/bin/bash"])
        w.add(term);
        w.show_all()
        Gtk.main()
    end
  end
  
  class Terminal < Vte::Terminal
    defn [:string[]]
    def spawn(a)
      pid = :Pid?.nil!
      spawn_sync(Vte::PtyFlags::DEFAULT,nil,a,nil, SpawnFlags::DO_NOT_REAP_CHILD,nil,out(pid),nil)
      return pid
    end
  end
end
