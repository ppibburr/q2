require pkg: 'gtk+-3.0'

namespace module CTags
  @@tags = :Tag[].empty!
  
  class Tag
    defn [:string?, :string?, :string?, :string?]
    def initialize sym, l,t
      @symbol = sym
      @line   = l
      @type   = t
    end
  end
 
  def self.parse f 
    buff = read_pipe("ctags -f - -x --sort=no #{__FILE__}")[0].split("\n")
  
    buff.each do |l|
       if l != ""
       a= /(\w+)\s/.split(l)
       z=5
       q=3
       o = 0
       o = 2 if a[5] == "method"
       tags << Tag.new(a[1],a[z+o],a[q+o])
      end
    end
   
   tags.each do |t|
     p t.symbol
   end 
    
    return tags
  end
  
  def self.read_pipe  c
      stdout = :string.nil!;
      stderr = :string.nil!;
      status = :int?.nil!;

    
      Process.spawn_command_line_sync(c,
                                    out(stdout),
                                    out(stderr),
                                    out(status));

      return [stdout, stderr]    
  end

  class TagList < Gtk::ScrolledWindow
    def initialize
      @l = Gtk::ListBox.new()
      add_with_viewport @l
    end
    
    def update tags
      @l.get_children().each do |c| @l.remove c end
      tags.each do |tag|
        s = "#{tag.type} | #{tag.symbol}"
        @l.insert(Gtk::Label.new(s),-1)
      end
    end
 
    defn [:string[]]
    def self.main args
      Gtk.init ref(args)
      w=Gtk::Window.new
      w.resize 350,550
      w.add tl=TagList.new
      tl.update CTags.parse("./tags")
      w.show_all()
      Gtk.main()
    end 
  end
end
