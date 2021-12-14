require pkg: 'gtk+-3.0'
require pkg: 'glib-2.0'
require pkg: 'gio-2.0'

namespace 
module Q
  class Options
    def initialize d
      @dict = d
    end 

    defn [string], Variant?
    def get k
      t = dict.lookup_value(k, VariantType.ANY)
      return t
    end 
    
    defn [string], :bool
    def contains k
      return @dict.contains(k)
    end
  end

  class Application < Gtk::Application
    defn [:string]
    def initialize name
      Object(application_id: name,
	              flags: GLib::ApplicationFlags::HANDLES_COMMAND_LINE | GLib::ApplicationFlags::HANDLES_OPEN)
        
      command_line.connect(do_command_line)
      
      open.connect() do |files|
        files.each do |file|
          open_file(file)
        end
        
        activate()
      end
      
      activate.connect() do
        @window = create_window() unless @window
        @window.present() if @window
      end
    end
    
    defn [string,char,OptionFlags,OptionArg,string,string?]
    def add_option l, s, flags, t, desc, arg_desc
      add_main_option(l,s,flags,t,desc,arg_desc)
    end

    signal() {
      defn [Q.Options, ApplicationCommandLine], :int
      def handle_options opts, command_line; end      
      defn [], Gtk::ApplicationWindow?
      def create_window;end      
      def open_file file;end      
    }
    
    defn [GLib::ApplicationCommandLine], :int
    def do_command_line(command_line)
      options = command_line.get_options_dict()
      opts = Q.Options.new(options)
      code    = self.handle_options(opts, command_line)

      if code == 0
        activate()
      
        files = File[].nil!
        args = command_line.get_arguments() 
        args = args[1..(args.length)]

        for arg in args    
          files << File.new_for_path(Filename.canonicalize(command_line.create_file_for_arg(arg).get_path(), command_line.get_cwd()))
        end
      
        self.open(files, "open")
        
        return 0
      
      elsif code < 0
        return 0
      
      else
        return code
      end
    end
  end
end

if __FILE__ == $0
  namespace module Foo
    class AppWindow < Gtk::ApplicationWindow
      def initialize ins
        Object(application: ins, title: "my window")
      end
    end
    
    class App < Q::Application
      def initialize app
        super(app)
        
        add_main_option("test", `'t'`, GLib::OptionFlags::NONE, OptionArg.STRING, "Command line test", "test value")
        
        handle_options.connect() do |opts, cl|
          if opts["test"]
            cl.print(string.cast!(opts['test'])+"\n")

            next -1
          end
          
          next 0
        end  
        
        open_file.connect() do |f|
          p f.get_path()
        end  
      
        create_window.connect() do
          next AppWindow.new(self)
        end
      end
    end
  end
  
  Foo::App.new("org.q.qode").run(Q.args)
end
