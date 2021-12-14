require pkg: 'webkit2gtk-web-extension-4.0'

namespace; module Q
  class WebExtension < Object
    attr_reader(:extension) {WebKit::WebExtension}
    attr_reader(:data) {Variant?}
  
    defn [WebKit::WebExtension, Variant?]
    def initialize extension, data
      @_extension = extension
      @_data      = data
      
      ref()
      
      @extension.page_created.connect() do |pg|
        page_created(pg)
      end
    end
    
    attr_reader(default_script_world: WebKit::ScriptWorld.get_default()) {WebKit::ScriptWorld}
    
    signal() {
      defn [WebKit::WebPage]
      def page_created(pg); end
    }
  end
end 
