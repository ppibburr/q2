require 'optparse'
class Options
  def self.parse(args)
    options = {}

    opts = OptionParser.new do |opts|
      opts.on('-l', '--library NAME', 'set library name to NAME') do |name|
        options[:lib_name] = name
        options[:shared] = true
      end
      
      opts.on('-B', '--budgie-plugin NAME', 'set plugin name to NAME') do |name|
        options[:lib_name] = name
        options[:budgie_plugin] = true
      end      

      opts.on('-s', '--shared', 'make shared library') do
        options[:shared] = true
      end

      opts.on('-g', '--gir', 'make gobject-inrospection shared library') do
        options[:shared] = true
        options[:gir]    = true
        $gir = true
      end

      opts.on('-e', '--execute CODE', 'execute CODE') do |code|
        options[:code] = code
      end
 
      opts.on('-r', '--run', 'run the result') do
        options[:run] = true
      end

      opts.on('-t', '--tags', 'dump symbol information') do
        options[:tags] = true
      end
      
      opts.on('-E', '--list-extensions', 'list gir compatible extensions') do
        options[:list_extensions] = true
      end
      
      opts.on('-d', '--doc', 'generate yard documentation') do
        options[:doc] = true
      end   
      
      opts.on(nil, '--clobber', 'deep clean removal of generated files') do
        options[:clobber] = true
      end   
      
       opts.on('-C', '--clobber-lib LIB', 'deep clean generated files for LIB') do |lib|
        options[:clobber_lib] = lib
      end                       
    end       
      
    opts.parse!(args)

    options
  end
end

def options
 $options ||= Options.parse ARGV
end
