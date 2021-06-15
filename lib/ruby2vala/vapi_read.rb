class T
  attr_accessor :n, :c, :i, :f, :p, :m, :t,:parent
  def initialize pa,nm, n: nil, t: nil, c: nil, i: nil, f: nil, p: nil, m: nil
    @n,@t,@c,@i,@f,@p,@m = n,t,c,i,f,p,m
    @parent = pa
    @nm=nm
    $m[name] = t if t
  end
  def name
    (@parent ? @parent.name+"." : '')+@nm
  end
end

def vapi_import p=ARGV[0]
f = `locate #{p}.vapi`.strip.split("\n").last
return unless f && f!=''

buff=open(f).read.split("\n")



$m={}
$open = nil
buff.each do |l|
  if l=~/namespace (.*)\{/
    $open = T.new($open, $1.strip, n: true)
  elsif l=~/public class (.*)\{/
    $open = T.new($open, $1.split(":")[0].strip, c: true)
  elsif l=~/public interface (.*)\{/
    $open = T.new($open, $1.split(":")[0].strip, i: true)
  elsif l=~/public enum (.*)\{/
    $open = T.new($open, $1.split(":")[0].strip, i: true)
  elsif l=~/public (.*)\(.*\);/
    a=$1.split(" ")
    n=a[-1]
    t=a[0..-2].join(" ").gsub(/weak|unowned|signal|static/,'')
    T.new($open, n, m: true, t: t.strip)
  elsif l=~/public (.*)\{.*\}/
    a=$1.split(" ")
    n=a[-1]
    t=a[0..-2].join(" ").gsub(/weak|unowned|signal|static/,'')
    T.new($open, n, m: true, t: t.strip)
  elsif l.strip=~/^\}/
    $open=$open.parent if $open && $open.parent
  end
end

$m
end

vapi_import if __FILE__ == $0
