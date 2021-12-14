require q: "./qapplet.q"
require pkg: "ruby"

namespace
module BudgieRuby
  class Applet < Q::Applet
    `public static bool ruby = false`
  
    override!
    def init
      @rb_path = ""
      @rb_path =  plugin_info.get_module_dir()+"/"+plugin_info.get_name()+".rb"
      init_rb() if Applet.ruby == false 
      Applet.ruby = true
      load_rb("#{`((int64)(void*)this)`}", @rb_path)  
    end
  end

  defn [], 'void*'
  def self.init_rb()
    RubyLoad.init();
    RubyLoad.init_loadpath();
    RubyLoad.enc_find_index("encdb");
  
    RubyLoad.eval_string("require('rubygems')", out(state)); 
    RubyLoad.eval_string("require('gtk3')",out(state))
  
    state = int?.nil!
    return RubyLoad.eval_string("#{DATA.read}",out(state))
  end

  defn [string,string], 'void*'
  def self.load_rb(data, path)
    state = int?.nil!
    return RubyLoad.eval_string("init_applet(#{data}, '#{path}');", out(state))
  end
end


__END__
require './qapplet.rb'

APPLETS={}

def init_applet ptr, path
  applet = APPLETS[File.expand_path(path)]=GObjectIntrospection::Loader.instantiate_gobject_pointer(ptr)
  load path
rescue => e
  p e
end

