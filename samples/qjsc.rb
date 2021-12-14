require(pkg: "javascriptcoregtk-4.0")
require pkg: 'gee-0.8'

namespace; module Q 
  class JSClass < Object
    `public static Gee.HashMap<JSC.Value,Object?> omap;`
    `public static Gee.HashMap<Type,JSC.Class?> map;`
    `static construct {map = new Gee.HashMap<Type, JSC.Class?>();omap = new Gee.HashMap<JSC.Value, Object?>();}`
    attr_reader(:jsc) {JSC::Class}
    defn [JSC::Context, string, Type]#, JSC::ClassConstructorCb?]
    def initialize c, name, type#,cb
      @_jsc = c.register_class(name, nil,nil) do |cls|
        #JSC::Class.cast!(cls).unref()
        p "unref"
      end
      
      map[type]=@jsc
      
      ObjectClass.cast!(type.class_ref()).list_properties().each do |spec|
        t = spec.value_type
        t = typeof(JSC::Value) if !!t.is_object()

        @jsc.add_property(spec.get_name(), t, proc do |o|
          if spec.value_type == typeof(`int`)
            v = Value.cast!(spec.get_default_value())
            o.get_property(spec.get_name(), ref(v));
            next v.get_int()
            
          elsif spec.value_type == typeof(`double`) 
            v1 = Value.cast!(spec.get_default_value())
            o.get_property(spec.get_name(), ref(v1));
            next `(double?)v1.get_double()`
          
          elsif spec.value_type == typeof(`string`)
            v2 = Value.cast!(spec.get_default_value())
            o.get_property(spec.get_name(), ref(v2));
            next `(string?)v2.strdup_contents()` 
         
          elsif spec.value_type == typeof(JSC::Value)
            val = JSC::Value.nil!
            o.get(spec.get_name(), out(val))
            next val
         
          elsif spec.value_type == typeof(JSC::Value[])
            val = JSC::Value[].nil!
            o.get(spec.get_name(), out(val))
            next val       
         
          elsif !!spec.value_type.is_object()
            obj = Object.nil!
            o.get(spec.get_name(), out(obj))

            jobj = JSClass.ensure_wrapper(c,obj)

            next jobj
         
          else
            next nil
          end
        end, proc do |o, t|
          o.set(spec.get_name(), t)
        end)
      end

      ctor = @jsc.add_constructor(name, proc do |a| 
        `Object? o = Object.new(type)`
        v=JSClass.ensure_wrapper(c,o)       
        next o 
      end, type)
      
      c.set_value(@jsc.get_name(), ctor);    
    
      @jsc.add_property("gtype", typeof(JSC::Value), proc do next JSC::Value.new_number(c, type) end, nil)
      @jsc.add_property("gtypeName", typeof(JSC::Value), proc do next JSC::Value.new_string(c, type.name()) end, nil)
    end
    
    defn [JSC::Context, Object], JSC::Value
    def self.ensure_wrapper c,obj
      w = map[obj.get_type()]

      if !w
        JSClass.new(c,obj.get_type().name(), obj.get_type())
        w = map[obj.get_type()]
      end

      jobj = JSC::Value.new_object(c,obj,w)
      omap[jobj] = obj
      
      return jobj  
    end
    
    defn [JSC::Value], Object?
    def self.wrapped(v)
      return omap[v]
    end
    
    defn [string?, Type, JSC::ClassMethodCb], JSClass
    def function n, rt, cb
      @jsc.add_method(n, cb, rt)
      return self
    end
  end
end
