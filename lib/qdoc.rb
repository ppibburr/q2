require 'json'

MAP = {children: {}, props: {}, fields: {}}

def mkpath p
  r=MAP
  p.split(".").each do |q| r=(r[:children][q] ||= {children: {}, props: {}, fields: {}}) end
  r
end

def doc tags, files
  files=files.map do |f|
    File.expand_path(f)
  end
  tags.each do |t|
    next unless files.index(t["file"])
    p = mkpath(t["parent"].to_s)
    
    if t["kind"] !~ /field|property/
      n = (p[:children][t["ruby"]||t["symbol"]] ||= {children: {}, props: {}, fields: {}})
      n[:tag] = t    
      n[:props]  = {}
      n[:fields] = {}
    elsif t["kind"] == "property"
      p[:props][t["ruby"]||t["symbol"]] =  t 
    elsif t["kind"] == "field"
      p[:fields][t["ruby"]||t["symbol"]] =  t 
    end
  end
 
 
  iter MAP
end

def iter a, i=0
  a[:children].each_pair do |k, node|
    #sa = node[:children].find_all do |c,n|
    #  n[:tag]['kind'] == 'signal'
    #end
    
    #sa.each do |n,c|
    #  node[:children].delete(n)
    #  node[:children][n] = c
    #end
  
    t = node[:tag]
    case t["kind"]
    when /Namespace|Class|Module/
      puts
      q = "module"
      q = "class" if t["kind"] == "Class"
      puts i, t['comments']
      node[:props].each do |n, p|
        puts i,"# @attr #{p['ruby']||p['symbol']} [#{p['return_type']}] +property+ #{p['comments']}"
      end

      node[:fields].each do |n, p|
        puts i,"# @attr #{p['ruby']||p['symbol']} [#{p['return_type']}] +field+ #{p['comments']}"
      end

      if sc = t['superclass']
        sc = sc.gsub(".","::")  
        sc = " < #{sc}"
      end
      
      puts i, "#{q} #{t['ruby']||t['symbol']}#{sc}"
      
      t["includes"].each do |a|
        puts i+2, "include #{a.gsub(".","::")}"
      end
      iter node, i+2
      puts i, "end"
    when /method|signal|constructor/
      puts
      puts i, "# +signal+" if t['kind'] == 'signal'
      puts i, "# +delegate+" if t['kind'] == 'delegate'      
      puts i, "#"+t['comments']
      z=-1
      t['args'].each do |q|
        puts i, "# @param [#{q}] arg#{z+=1}"
      end
      nt = ''
      nt = " +nullable+" if t['return_type'] =~ /\?$/
      puts i, "# @return [#{t['return_type'].gsub(".", '::').gsub(/^\:/,'').gsub(/\?$/,'')}]#{nt}"
      z=-1
      puts i,"def #{t['ruby']}(#{t['args'].map do |q| "arg#{z+=1}" end.join(", ")})"
      puts i,"end"
      
      if ["get","set"].index(t['ruby'])
        puts i, "alias :[] :#{t['ruby']}" if t['ruby'] == 'get'
        puts i, "alias :[]= :#{t['ruby']}" if t['ruby'] == 'set'
      end
    end
  end
end

$DOC = ""

def puts i=0, q=''
  $DOC << "#{" "*i}#{q}\n"
end



