class T
  attr_accessor :n, :c, :i, :f, :p, :m, :t,:parent, :sc, :aa
  def initialize pa,nm, n: nil, t: nil, c: nil, i: nil, f: nil, p: nil, m: nil, sc: nil, aa: nil, inc: nil
    @n,@t,@c,@i,@f,@p,@m = n,t,c,i,f,p,m
    @sc = sc
    @inc = inc
    @parent = pa
    @nm=nm
    @aa = aa
    $m[name] = t if t
    $m[name] = {superclass: sc, includes: inc} if sc || inc
    $m[name] = self if aa
    #p parent if m && (n=="test")
  end
  def name
    (@parent ? @parent.name+"." : '')+@nm
  end
end
VC={}
def vapi_import p=ARGV[0]
  tf=tf="./q_generated/q_pkg/#{p}.qpk"
  return $m=VC[tf] if VC[tf]
  if File.exist?(tf)
    return VC[tf]=$m=Marshal.load(open(tf).read)
  end

f = `locate #{p}.vapi`.strip.split("\n").last
f = nil if f && (f.strip=='')
f ||= Dir.glob("./#{p}.vapi")[0]

return unless f && (f!='')

buff=open(f).read.split("\n")

$m={}
$open = nil
buff.each do |l|
  if l=~/namespace (.*)\{/
    $open = T.new($open, $1.strip, n: true)
  elsif l=~/public class (.*)\{/
    sc = $1.split(":")[1].strip.split(",")[0] rescue nil
    inc = $1.split(":")[1].strip.split(",")[1..-1] rescue []
    $open = T.new($open, $1.split(":")[0].strip, c: true, sc: sc, inc: inc.map do |q| q.strip end)
  elsif l=~/public interface (.*)\{/
    inc = $1.split(":")[1].strip.split(",") rescue []
    $open = T.new($open, $1.split(":")[0].strip, i: true, inc: inc.map do |q| q.strip end)
  elsif l=~/public enum (.*)\{/
    $open = T.new($open, $1.split(":")[0].strip, i: true)
  elsif l=~/public (.*)\((.*)\);/
    a=$1.split(" ")
    al=$2
    n=a[-1]
    t=a[0..-2].join(" ").gsub(/weak|unowned|signal|static|abstract|virtual/,'')
    aa={}

    al.split(",").map do |a|

      r=a.split(' ')
      an = r[-1]
      at = r[-2]
      aa[an]=at
    end if al
    T.new($open, n.gsub("@",''), m: true, t: t.strip,aa: aa)
  elsif l=~/public (.*)\{/
    a=$1.strip.split(" ")
    n=a[-1]
    t=a[0..-2].join(" ").gsub(/weak|unowned|signal|static|abstract|virtual/,'')
    T.new($open, n, m: true, t: t.strip)
  elsif l.strip=~/^\}/
    $open=$open.parent if $open && $open.parent
  end
end

`mkdir -p #{File.dirname(tf)}`

File.open(tf,'w') do |f| f.puts Marshal.dump($m) end

VC[tf]=$m
end

vapi_import if __FILE__ == $0
