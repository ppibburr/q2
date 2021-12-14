def gen_stub lib_name
"""
# Automatically generated file
# Stub loader for: #{lib_name}
# Compile time: #{Time.now}
# path: #{Dir.getwd}


require 'gobject-introspection'
GIRepository = GObjectIntrospection
Dir.glob(File.dirname(__FILE__)+'/ext/'+'*'+'/lib').each do |q|
  p search: q
  GIRepository.prepend_typelib_path(File.expand_path(q))
end

$: << File.dirname(__FILE__)

#{$libs.map do |l| File.exist?("./ext/#{l}") ? "require '#{l}'\n" : "" end.join()}

module #{lib_name.capitalize}
  p lib: '#{lib_name}'
  class << self
    @initialized = false
    def init 
      return if @initialized
      @initialized = true
      loader = Loader.new(self)
      p load: '#{lib_name}'
      od=Dir.getwd
      Dir.chdir './ext/#{lib_name}/lib'
      loader.load(\"#{lib_name}\")
      Dir.chdir od
    end
  end

  class Loader < GObjectIntrospection::Loader
    def self.load *o
      p o
      super
    end
  end
  init
end
"""
end

def write_stub path, buff
  File.open(File.expand_path(path), "w") do |f|
    f.puts buff
  end
end

def stub lib_name,  path =  "./#{lib_name.downcase}.rb"
  buff = gen_stub lib_name

  write_stub path, buff
  
  return path
end

if __FILE__ == $0
  buff = gen_stub ARGV[0]
  path =  "./#{ARGV[0].downcase}.rb"
  write_stub path, buff
end
