require  q: 'samples/qjsc.rb'
require  q: 'samples/web_extension.rb'

class Obj2 < Object
  attr_reader(moof: 69)
end

class Obj3 < Object
  attr_reader(quux: 23)
end

class Obj4 < Object
  attr_reader(bar: 88)
end

class MyJSObj < Object
  JS!
  
  attr_accessor(prop1: 69)
  attr_accessor(prop2: Obj3.new())
  
  defn [int, Object, string, JSC::Value], Object
  def foo i,o,s, v
    puts i
    puts o.get_type().name()
    puts s
    puts v.object_get_property("test").to_string()
    
    return self
  end
  
  defn [Object], string
  def bar o
    s = o.get_type().name()
    puts s
    
    return s
  end
  
  signal() {
    defn [int], bool
    def sig(a); end
  }  
end

class MyExtension < Q::WebExtension
  defn [WebKit::WebExtension, Variant?]
  def initialize extension, data
    super(extension, data)
   
    @default_script_world.window_object_cleared.connect() do |pg, fr|
      c = fr.get_js_context_for_script_world(@default_script_world)
      
      # Make Obj2 available to javascript via +new Obj2()+
      # Wraps all properties
      # add method +foo+ to JS<Obj2>
      Q::JSClass.new(c, "Obj2", typeof(Obj2)).function("foo", Type::STRING) do |wrapped, args|
        p args[0]
        next "ok".dup()
      end
      
      # Make +MyJSObj+ available to js as +new MyJSObj()+
      # wraps all methods and properties 
      MyJSObj.register(c)
      
      # Makes +Obj4+ available to JS as +new Obj4()+
      # wraps properties
      # sets as +global_object#obj4+
      c.set_value("obj4", Q.JSClass.ensure_wrapper(c,Obj4.new()))    
    end
  
    page_created.connect() do |page|
      message("Page %" + uint64.FORMAT + " created", page.get_id());
      
      page.document_loaded.connect() do   
        page.get_main_frame().get_js_context().evaluate(DATA.read, -1)
      end
    end
  end
end

__END__
alert(obj4);
alert(obj4.gtype);
alert(obj4.gtypeName);
alert(new MyJSObj().foo(new MyJSObj().prop1, new Obj2(), "hello", {test: "bob"}));
alert(new MyJSObj().prop2.quux);
alert(new Obj3()); // Obj3 automatically partial wrapped



