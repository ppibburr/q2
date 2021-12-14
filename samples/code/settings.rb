namespace Qode
  class Settings
    attr_accessor(:files) {:string[]}
    attr_accessor(:theme) {:string}
    
    def restore_session(app)
      files.each do |f|
        file = File.new_for_path(f)
        d = app.open_file(file)
        editor = Qode:::Document.cast!(d)
        editor.buffer.style_scheme = Gtk::SourceStyleSchemeManager.get_default().get_scheme(@theme)
      end
    end
  end
end

__END__
{
  "files": [
    "/home/ppibburr/huh.rb" 
  ],
  
  "theme": "tango"
}
