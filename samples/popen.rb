require pkg: 'gio-2.0'
require pkg: 'gio-unix-2.0'

namespace 
module POpen
  class Watch < Object
    # The pid of the process
    attr_accessor(:pid) {:Pid?}
    attr_accessor(:ok) {:bool}
    attr_accessor(:pipe) {:Pipe?}
    
    def initialize(pid)
      @pid = pid
      @ok = false
    end
    
    # called when the ChildWatch for exiting is invoked
    delegate() {
      defn [:Pid?, :int?]
      def exit_cb(pid, status); end
    }
    # Connects a ChildWatch to the process
    defn [:exit_cb], :Watch?
    def at_exit(cb)
      if @ok != true
        GLib::Idle.add() do
          cb(nil,nil)
          next(false)
        end
        return self
      end
     
      ChildWatch.add(@pid) do |_pid, status|
        # Triggered when the child indicated by child_pid exits
        cb(_pid, Process.exit_status(status))
        Process.close_pid(_pid);
      end 
      
      return self
    end
  end

  # Provides simple IO to the process
  class Pipe < Object
    # The process pid
    attr_accessor(:pid) {:Pid}
    # stdin fd
    attr_accessor(:stdin, :stdout, :stderr) {:int}         


    def initialize(pid, stdin, stdout, stderr)

      Object(pid: pid, stdin: stdin, stdout: stdout, stderr: stderr)
      
      init()       
    end
    
    def init
      @io_in  = FileStream?.nil!
      @io_in  = GLib::FileStream.fdopen(stdin,"w")
      @io_err = GLib::IOChannel.new_unix_new(@stderr)
      @io_out = GLib::IOChannel.new_unix_new(@stdout)    
    end

    # Writes a string to the process stdin
    # performs `flush` on the stream when completed
    defn [:string]
    def puts(str)
      @io_in.puts(str)
      @io_in.putc(`'\n'`)
      @io_in.flush()
    end
    
    def close_write()
      GLib::UnixInputStream.new(@io_in.fileno(), true).close()    
    end
    
    # called when a line is read from the @io_out IOChannel
    signal() {
      defn [:string]
      def on_read(str)
      end
    }
    
    # Begins reading from the @io_out via IOChannel.add_watch
    def read()
      @io_out.add_watch(GLib::IOCondition::IN | GLib::IOCondition::HUP) do |channel, condition|

        if condition == GLib::IOCondition::HUP
          next false
        end
        
     #   begin
          line = :string.nil!
          channel.read_line(out(line), nil, nil)
          on_read(line)
      
          next true
        
      #  rescue IOChannelError => e
      #    return false
        
      #  rescue ConvertError => e
      #    return false
      #  end
      end
    end
  end

  # @yieldparam obj [Pipe] the POpen::Pipe conencted to the process
  delegate() {
    defn [:Pipe]
    def popen_cb(obj);end
  }
  
  # Opens a process by building a command from +args+ and connects pipes
  defn [:string[], :popen_cb], :Watch?
  def self.popen(args, cb)
    stdout = int.nil!
    stderr = int.nil!
    stdin  = int.nil!
    
    pid = :Pid.nil!    
    
    #begin
      Process.spawn_async_with_pipes(nil,
        args,
        Environ.get(),
        SpawnFlags::SEARCH_PATH | SpawnFlags::DO_NOT_REAP_CHILD,
        nil,
        out(pid),
        out(stdin),
        out(stdout),
        out(stderr));
        
      pipe = Pipe.new(pid, stdin, stdout ,stderr)
      
      cb(pipe)
      
      watch = POpen::Watch.new(pid) 
      watch.pipe = pipe
      watch.ok = true
      
      return watch  
    
    #rescue SpawnError => e
    #  return POpen::Watch.new(pid)
    #end
  end

def self.test
loop=GLib.MainLoop.new()
  POpen.popen(["/usr/bin/ruby", "./echo.rb"]) do |obj|
    obj.puts("foo")
    
    obj.on_read.connect() do |l|
      print("#{l}")
    end
    
    obj.read()
  end.at_exit() do |pid, status|
    if pid == nil
      print("Process failed to execute\n")
    else
      print("Process #{pid}: Exited with, #{status}\n")
    end
  end
loop.run()
end
end
