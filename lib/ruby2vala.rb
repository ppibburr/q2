#!/usr/bin/env ruby -w

require "rubygems"
require "sexp_processor"
def f_path file
  if File.exist?(f=File.expand_path("#{$pdir}/"+file))
    return f
  end
  if File.exist?(f=File.expand_path("./"+file))
    return f
  end
  if File.exist?(f=File.expand_path(file))
    return f
  else
    raise "Q - No such file: #{file}"
  end
end
$DATA={}
def data file
  d = "begin;puts DATA.read;rescue;end; exit;\n#{open(file).read}"
  File.open("./.d.q.rb","w") do |f|
    f.puts d
  end
  $DATA[file] = `ruby ./.d.q.rb`
end

def q_require file
  if file.is_a?(Hash)
    $pkg << file[:pkg] unless $pkg.index(file[:pkg])
    return nil
  end
  
  return nil if file == "Q"

  file = f_path(file)
 
  return nil if $sa[file]
  
  data(file)
  
  $ruby << (ruby = file == "-" ? $stdin.read : File.read(file))
  
  $sa[file] ||= (sexp = $parser.process(ruby, file))
  
  sexp
end


class Scope
  attr_reader :map, :parent, :fields, :args
  attr_accessor :name, :superclass, :return_type
  @@ins = []
  
  def self.find s, &b
    i = @@ins.find do |q| q.name == s end
    b.call i
  end
  
  def to_s!
    to_s
  end

  def to_s
    @rt||=return_type.to_s
  end
  
  def initialize p=nil
    @@ins << self
    @parent=p
    @map={}
    @name=''
    @fields={}
    @args=[]
  end  
  
  def declared? q

    q=q.to_s.gsub(/\(.*?\)/,'').gsub("@",'') if q

    z=(self.map[q] || (parent ? parent.declared?(q) : nil) || (superclass ? Scope.find(superclass) do |s| s ? s.declared?(q) : nil end : nil)) if q

    return z if q =~ /\./

    z || (("#{self.name}.#{q}" != q) ? declared?("#{self.name}.#{q}") : nil)
  end
  
  def guess_type(what)
      what=what.to_s!
      if t=declared?(what)  
        t
      else
        case what
        when /^new (.*)/
          q=$1
          is_new?(what) ? q : :var
        when /^\"/
          "string"
        when /^[0-9]+$/
          "int"
        when /^\([0-9]+\)$/
          "int"
        when /^[0-9]+\.[0-9]+$/
          "double"
        when /^\([0-9]+\.[0-9]+\)$/
          "double"
        when /\{[0-9]+/
          'int[]'
        when /\{\"/
          "string[]"
        when /\{(.*)(\,|\})/
          z=declared?($1)
          if z!=:var
            z.to_s+"[]" 
          else
            :var
          end
        else
          :var
        end
      end  
  end
  
  def assign q, what,cs=nil
    q=q.to_s.gsub(/^\./,'')
    
    cs = self unless cs
    unless qq=cs.declared?(q)
      qq = (($gt.to_s != 'var') ? $gt : nil) || cs.guess_type(what) || :var

      self.map[q] = qq
    end
      $gt = nil
      qq
  end
end

def is_new? s
  (s.gsub(/.*?\)/,'') == "") &&
    s.scan(/.*?\)/).last == ")"
end

class LocalScope < Scope

  
end

# :stopdoc:
# REFACTOR: stolen from ruby_parser
class Regexp
  unless defined? ENC_NONE then
    ENC_NONE = /x/n.options
    ENC_EUC  = /x/e.options
    ENC_SJIS = /x/s.options
    ENC_UTF8 = /x/u.options
  end

  unless defined? CODES then
    CODES = {
      EXTENDED   => "x",
      IGNORECASE => "i",
      MULTILINE  => "m",
      ENC_NONE   => "n",
      ENC_EUC    => "e",
      ENC_SJIS   => "s",
      ENC_UTF8   => "u",
    }
  end
end
# :startdoc:
class Sexp
  # add arglist because we introduce the new array type in this file
  @@array_types << :arglist
end
##
# Generate ruby code from a sexp.

class Ruby2Ruby < SexpProcessor
  VERSION = "2.4.4" # :nodoc:

  # cutoff for one-liners
  LINE_LENGTH = 78

  # binary operation messages
  BINARY = [:<=>, :==, :<, :>, :<=, :>=, :-, :+, :*, :/, :%, :<<, :>>, :**, :"!=", :^, :|, :&]

  ##
  # Nodes that represent assignment and probably need () around them.
  #
  # TODO: this should be replaced with full precedence support :/

  ASSIGN_NODES = [
                  :dasgn,
                  :flip2,
                  :flip3,
                  :lasgn,
                  :masgn,
                  :match3,
                  :attrasgn,
                  :op_asgn1,
                  :op_asgn2,
                  :op_asgn_and,
                  :op_asgn_or,
                  :return,
                  :if, # HACK
                  :rescue,
                 ]

  ##
  # Some sexp types are OK without parens when appearing as hash values.
  # This list can include `:call`s because they're always printed with parens
  # around their arguments. For example:
  #
  #     { :foo => (bar("baz")) } # The outer parens are unnecessary
  #     { :foo => bar("baz") }   # This is the normal code style

  HASH_VAL_NO_PAREN = [
    :call,
    :false,
    :lit,
    :lvar,
    :nil,
    :str,
    :true,
  ]

  def initialize # :nodoc:
    super
    @indent = "  "
    self.require_empty = false
    self.strict = false
    self.expected = String

    @calls = []
    self.unsupported
    # self.debug[:defn] = /zsuper/
  end

  ############################################################
  # Processors

  def process *o
  
    if scope==$scope[0] && !$q
      $q=true
      r=super
      r=fmt_body(r)
      $q=false
      r
    else
      r=super
    end
  end

  def process_arg_paren *o;exit;end

  def process_alias exp # :nodoc:
    _, lhs, rhs = exp

    parenthesize "alias #{process lhs} #{process rhs}"
  end

  def process_and exp # :nodoc:
    _, lhs, rhs = exp

    parenthesize "#{process lhs} and #{process rhs}"
  end

  def process_arglist exp # custom made node # :nodoc:
    _, *args = exp

    args.map { |arg|
      code = process arg
      arg.sexp_type == :rescue ? "(#{code})" : code
    }.join ", "
  end

  def process_args exp # :nodoc:
    _, *args = exp

    shadow = []

    args = args.map { |arg|
      case arg
      when Symbol then
        arg
      when Sexp then
        case arg.sexp_type
        when :lasgn then
          process(arg)
        when :masgn then
          process(arg)
        when :kwarg then
          _, k, v = arg
          "#{k}: #{process v}"
        when :shadow then
          shadow << arg[1]
          next
        else
          raise "unknown arg type #{arg.first.inspect}"
        end
      when nil then
        ""
      else
        raise "unknown arg type #{arg.inspect}"
      end
    }.compact

    $procs = []
    a=[]
    args.each do |q|
      if q.to_s =~ /^\&(.*)/
        $procs << $1
        a << $1
      else
        a << q
      end
    end
    
    args   = a.join(", ").strip
   
    shadow = shadow.join(", ").strip
    shadow = "; #{shadow}" unless shadow.empty?

    "(%s%s)" % [args, shadow]
  end

  def process_array exp # :nodoc:
    "{#{process_arglist exp}}"
  end

  def process_attrasgn exp # :nodoc:
    _, recv, name, *args = exp

    rhs = args.pop
    args = s(:array, *args)
    receiver = process recv

    case name
    when :[]= then
      args = process args
      args = args.gsub(/\{|\}/,'')
      args = "[#{args}]"
      "#{receiver}#{args} = #{process rhs}"
    else
      raise "dunno what to do: #{args.inspect}" if args.size != 1 # s(:array)
      name = name.to_s.chomp "="
      if rhs && rhs != s(:arglist) then
        "#{receiver}.#{name} = #{process(rhs)}"
      else
        raise "dunno what to do: #{rhs.inspect}"
      end
    end
  end

  def process_back_ref exp # :nodoc:
    _, n = exp

    "$#{n}"
  end

  # TODO: figure out how to do rescue and ensure ENTIRELY w/o begin
  def process_begin exp # :nodoc:
    _, *rest = exp

    code = rest.map { |sexp|
      src = process sexp
      src = indent src unless src =~ /(^|\n)(rescue|ensure)/ # ensure no level 0 rescues
      src
    }
    code.unshift "begin"
    code.push "end"

    code.join "\n"
  end

  def mb? f='q'

    
    if !$mb && (scope == $scope[0])
    if (scope == $scope[0].map["main"])
    else
      $scope << ($scope[0].map["main"] ||= sc=LocalScope.new(scope))
    end
      $mb=true
      "static unowned string[] __q_args__;\n"+
      "static unowned string[] __q_argv__;\n"+
      "static int main(string[] _q_args) {\n%__Q_MAIN_DEC__\n"+
      "string[] qa = {\"#{f}\"};foreach (var q in _q_args) {qa += q;};"+
      "__q_argv__ = _q_args[1:-1];\n"+  
      "__q_args__ = qa;\n\n"
      
    else
      ""
    end
  end

  def process_block exp # :nodoc:

    _, *body = exp
    result = []
    result = ["\n\n"] if $FE

    result.push(*body.map { |sexp|
      s=''
      if ([:call, :lasgn].index(q=sexp[0]))
        if  q==:call
          if ![:namespace, :require, :generics, :delegate, :signal, :defn].index(sexp[2])
            p ss: s=mb?(exp.file) if !$mb
          end
        else
          s=mb?(exp.file) if  !$mb
        end
      end
    
      s=s+process(sexp)
      s
    })
    
    

    result << "// do nothing\n" if result.empty?
    result = parenthesize result.join "\n"
    result += "\n" unless result.start_with? "("
p result: result
    result
  end

  def process_block_pass exp # :nodoc:
    raise "huh?: #{exp.inspect}" if exp.size > 2

    _, sexp = exp

    r="&#{x=process sexp}"

    r
  end

  def process_break exp # :nodoc:
    _, arg = exp

    val = process arg

    if val then
      "break #{val}"
    else
      "break"
    end
  end

  class ::Object
    def to_s!
      to_s.gsub(/^\:/,'')
    end
    
    def to_t!
      to_s!.gsub(/\"/,'')
    end
  end
$ga=[]
  def process_call(exp, safe_call = false) # :nodoc:

   $gt = nil if $gt.to_s =~ /var|void/
    _, recv, name, *args = exp

    aa=open(exp.file).read.split("\n")[exp.line-1] =~ /(#{Regexp.escape("#{name.to_s!}")}\(.*\))/


    receiver_node_type = recv && recv.sexp_type
    receiver = process recv
    receiver = "(#{receiver})" if ASSIGN_NODES.include? receiver_node_type

    # args = []

    #  this allows us to do both old and new sexp forms:
    exp.push(*exp.pop[1..-1]) if exp.size == 1 && exp.first.first == :arglist
    
    @calls.push name
    gt = $gt
    $gt=nil
    r_args = []
    in_context :arglist do
      max = args.size - 1

      args = args.map.with_index { |arg, i|
        aa=false
        arg_type = arg.sexp_type
        is_empty_hash = arg == s(:hash)
        arg = process arg
        
        r_args << $gt
        next '' if arg.empty?

        strip_hash = (arg_type == :hash and
                      not BINARY.include? name and
                      not is_empty_hash and
                      (i == max or args[i + 1].sexp_type == :splat))
        wrap_arg = Ruby2Ruby::ASSIGN_NODES.include? arg_type

        arg = arg[2..-3] if strip_hash
        arg = "(#{arg})" if wrap_arg

        arg
      }.compact
    end
    $gt = gt
    case name
    when *BINARY then
      if safe_call
        "#{receiver}&.#{name}(#{args.join(", ")})"
      elsif args.length > 1
        "#{receiver}.#{name}(#{args.join(", ")})"
      else
        name = "+=" if name.to_s! == "<<"
        l=scope.guess_type(receiver)
        r=scope.guess_type(args.join(", "))
        if (lt=l.to_t!) != (rt=r.to_t!)
          case lt
          when "Value"
            l="%s"
            r="%s"
            l="(string)%s"     if rt=="string"  && ($gt = :string)
            l="(float)%s"      if rt=="float"   && ($gt = :float)
            l="(int)%s"        if rt=="int"     && ($gt = :int)
            l="(double)%s"     if rt=="double"  && ($gt = :double)
            
            r = r % args.join(",")
            l = l % receiver
            "#{l} #{name} #{r}"

          when "double"
            l="%s"
            r="%s"
            l="%s.to_string()" if (rt=="string") && ($gt = :string)
            r="(double)%s"     if (rt=="float")  && ($gt = :double)
            r="(double)%s"     if (rt=="int")    && ($gt = :double)
            r="(double)%s"     if (rt=="Value")  && ($gt = :Value)
            r = r % args.join(",")
            l = l % receiver
            "(#{l} #{name} #{r})"

          when "int"
            l="%s"
            r="%s"
            l="%s.to_string()" if rt=="string"  && ($gt = :string)
            l="(float)%s"      if rt=="float"   && ($gt = :float)
            l="(double)%s"     if rt=="double"  && ($gt = :double)
            r="(int)%s"        if rt=="Value"   && ($gt = :int)
            r = r % args.join(",")
            l = l % receiver
            "#{l} #{name} #{r}" 
          when "string"

            $gt = :string
            l="%s"
            r="%s"
            r="%s.to_string()" if rt=="int"
            r="%s.to_string()" if rt=="float"
            r="%s.to_string()" if rt=="double"
            r="(string)%s"     if rt=="Value"
           
            r = r % args.join(",")
            l = l % receiver

            "(#{l} #{name} #{r})" 
          else
            "(#{receiver} #{name} #{args.join(", ")})"
          end
        else
          $gt = lt
          "(#{receiver} #{name} #{args.join(", ")})"
        end
      end
    when :[] then
      receiver ||= "self"
      if $procs.index(receiver)
        "#{receiver}(#{args.join(", ")})"
      else
        "#{receiver}[#{args.join(", ")}]"
      end
    when :[]= then
      receiver ||= "self"
      rhs = args.pop
      "#{receiver}[#{args.join(", ")}] = #{rhs}"
    when :"!" then
      "(not #{receiver})"
    when :"-@" then
      "-#{receiver}"
    when :"+@" then
      "+#{receiver}"
    else
      args     = nil                    if args.empty?
      n_args=args
      args     = "(#{args.join(", ")})" if args
      
      receiver = "#{receiver}."         if receiver and not safe_call
      receiver = "#{receiver}&."        if receiver and safe_call

      if ['p','puts'].index(name.to_s)
        name = 'print'
        if n_args.length == 1
          args="((#{n_args.join}).to_string()+\"\\n\")"
        else
          n_args[0] = n_args[0].to_s+'+"\n"'
          args="(#{n_args.join(',')})"
        end
      end

      if receiver.to_s=="."
        receiver = ""
      end

      if ((n=name.to_s) == "read") && (receiver.to_s.gsub(/\.$/,'') == "File") 
        "new MappedFile#{args.gsub(/\)$/,', false)')}.get_contents()"
      elsif (n == "read") && (receiver.to_s.gsub(/\.$/,'') == "DATA") 
        ($DATA[File.expand_path(exp.file)] || "").inspect
      elsif (n == "require")
        s=scope
        p=$PROP
        f=$FE
        $PROP = nil
        $FE = nil
        $scope << $scope[0]  
        ns=$ns
        if sxp=eval("q_require#{args}")
          f=$sao.pop
          $sao << sxp.file
          $req[sxp.file] = (process(sxp))
          $sao << f        
        end
        $scope.pop
        $FE=f
        $ns=ns
        $PROP=p
        ''
      elsif n == "Value"
        $gt=:Value
        args
      elsif n == 'each'
        $FE = receiver
        ("foreach (")
      elsif (n == "class") && (receiver.to_s.gsub(/\.$/,'') == 'this')
        ""
      elsif n == "new"
        re="new #{$gt=receiver.to_s.gsub(/\.$/,'')}#{args.to_s == "" ? '()' : args}"

        re
      elsif n == "GenericType"
        "#{n_args[0]}<#{n_args[1..-1].map do |a| a.to_s! end.join(",")}>"
      elsif n == "generics"
        $generics = n_args.map do |a| a.to_s! end
        ''
      elsif n == 'sig'

        $SIGNAL = true
        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        ""
      elsif n == 'dele'

        $DELEGATE = true
        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        ""
      elsif n == 'defn'

        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        
        ""
      elsif n == "delegate"
          $DELG2 = []
          #push_sig n_args[0].to_s!, n_args[1].to_s!
          #("public signal #{n_args[1].to_s!} #{n_args[0].to_s!} {\n %s \n}") 
          "%s"     
      elsif n == "signal"
          $SIG2 = []
          #push_sig n_args[0].to_s!, n_args[1].to_s!
          #("public signal #{n_args[1].to_s!} #{n_args[0].to_s!} {\n %s \n}") 
          "%s"     
      
      elsif n == "property"
        $PROP = []
        if default = n_args[2]
          push_sig n_args[0].to_s!, n_args[1].to_s!
          ("public #{n_args[1].to_s!} #{n_args[0].to_s!} {\n get;set; default = #{default}; \n}")
          
        else
          push_sig n_args[0].to_s!, n_args[1].to_s!
          push_sig "_"+n_args[0].to_s!, n_args[1].to_s!
          "private #{n_args[1].to_s!} _#{n_args[0].to_s!};\n"+
          ("public #{n_args[1].to_s!} #{n_args[0].to_s!} {\n %s \n}")
        end
      elsif n == "attr_accessor"
        $PROP = n_args.map do |q| q.to_s! end
        $PROP.map do |a|
          ("public %s #{a} { get; set; }")
        end.join("\n")
      elsif n == "attr_reader"
        $PROP = n_args.map do |q| q.to_s! end
        $PROP.map do |a|
          ("public %s #{a} { get; }")
        end.join("\n")
      elsif n == "attr_writer"
        $PROP = n_args.map do |q| q.to_s! end
        $PROP.map do |a|
          ("public %s #{a} { set; }")
        end.join("\n")        
      elsif n == "to_s"
        $gt=:string
        if (t=scope.guess_type(r=receiver.to_s.gsub(/\.$/,'')).to_s) == 'Value'
          "(string)#{r}"
        else
          name = "to_string"
          "#{r}.#{name}"
        end
      elsif n == "to_i"
        $gt=:int
        if (t=scope.guess_type(r=receiver.to_s.gsub(/\.$/,'')).to_s) == 'string'
          "int.parse(#{r})"
        else
          name = ""
          "(int)#{r}#{name}"
        end        
      elsif n == "to_f"
        $gt=:double
        if (t=scope.guess_type(r=receiver.to_s.gsub(/\.$/,'')).to_s) == 'string'
          "double.parse(#{r})"
        else
          name = ""
          "(double)#{r}#{name}"
        end 
      elsif n == "namespace"
        $ns = true
        "namespace #{n_args[0]}"  
      else
        s=scope
        until !s.is_a?(LocalScope)
          s=s.parent
        end
        
        if m=s.declared?(name.to_s!)
          r_args.each_with_index do |q,i|
            if t=m.args[i]
            else
              m.args << (q || scope.guess_type(n_args[i].to_s!)    )   
            end
          end if n_args && m.is_a?(Scope)
        end



        # args = "()" if (args == '') || !args
        s="#{receiver}#{n}#{aa ? '()' : args}"
        qq=receiver.to_s!
        qq = "." if qq==''
        gt = $gt ? "#{$gt}." : (scope.guess_type(qq.gsub(/^\./,'').gsub(/\.$/,'')).to_s+"." || '')
        gt = '' if gt.to_s == 'var.'
        p XXX: qq.gsub(/^\./,'').gsub(/\.$/,''), g: n
        gt = scope.guess_type(x=gt+n).to_s
        p XXX3: x, s: scope.map.keys
        $gt=gt
        s
      end
    end
  ensure
    @calls.pop
  end

  def process_safe_call exp # :nodoc:
    process_call exp, :safe
  end

  def process_case exp # :nodoc:
    _, expr, *rest = exp

    result = []

    expr = process expr

    result << if expr then
                "case #{expr}"
              else
                "case"
              end

    result.concat rest.map { |pt|
      if pt and pt.sexp_type == :when
        "#{process pt}"
      else
        code = indent process pt
        code = indent("// do nothing") if code =~ /^\s*$/
        "else\n#{code}"
      end
    }

    result << "end"

    result.join "\n"
  end

  def process_cdecl exp # :nodoc:
    _, lhs, rhs = exp
    lhs = process lhs if Sexp === lhs
    if rhs then
      rhs = process rhs
      "#{lhs} = #{rhs}"
    else
      lhs.to_s
    end
  end

  def process_class exp # :nodoc:
    "#{exp.comments.split("\n").map do |q| "// "+q end.join("\n")}\npublic class #{util_module_or_class(exp, true)}"
  end

  def process_colon2 exp # :nodoc:
    _, lhs, rhs = exp

    "#{process lhs}.#{rhs}"
  end

  def process_colon3 exp # :nodoc:
    _, rhs = exp

    ":::#{rhs}"
  end

  def process_const exp # :nodoc:
    _, name = exp

    n=name.to_s
    if n =~ /(^ARGV$)|(^Q_ARGV$)/
      $gt = "string[]"
    end
    n.gsub(/^ARGV$/,"__q_argv__").gsub(/^Q_ARGV$/,"__q_args__")
  end

  def process_cvar exp # :nodoc:
    _, name = exp

    name.to_s
  end

  def process_cvasgn exp # :nodoc:
    _, lhs, rhs = exp

    "#{lhs} = #{process rhs}"
  end

  def process_cvdecl exp # :nodoc:
    _, lhs, rhs = exp

    "static #{lhs.to_s.gsub(/^\@\@/)} = #{process rhs}"
  end

  def process_defined exp # :nodoc:
    _, rhs = exp
    "defined? #{process rhs}"
  end

  def scope
    ($scope||=[]).last
  end

  $SIG = nil
  $KLASS = nil
  def process_defn(exp) # :nodoc:
    $procs = []
    ($scope||=[]) << LocalScope.new(scope)
    _, name, args, *body = exp

    name = "get" if name.to_s! == "[]"
    name = "set" if name.to_s! == "[]="
    
    comm = "#{exp.comments.split("\n").map do |q| "// "+q end.join("\n")}\n"

    args = process args
    scope.map.clear
    args = "" if args == "()"

    if $SIG
      args.gsub(/(^\()|(\)$)/,'').split(",").each_with_index do |q,i|
        scope.map[q.to_s.strip.to_s!.split("=")[0]] = $SIG[0][i].to_s! 
      end
    end

    body = s() if body == s(s(:nil)) # empty it out of a default nil expression

    # s(:defn, name, args, ivar|iasgn)
    case exp
    when s{ q(:defn, atom, t(:args), q(:ivar, atom)) } then # TODO: atom -> _
      _, ivar = body.first
      ivar = ivar.to_s[1..-1] # remove leading @
      reader = name.to_s
      $scope.pop
      return "public #{name.inspect} {}" if reader == ivar
    when s{ q(:defn, atom, t(:args), q(:iasgn, atom, q(:lvar, atom))) } then
      _, ivar, _val = body.first
      ivar = ivar.to_s[1..-1] # remove leading @
      reader = name.to_s.chomp "="
      $scope.pop
      return "public #{reader} {}" if reader == ivar
    end
    
    if name.to_s == 'initialize'
      name = $klass
    end

    static = name =~ /^this\./
    name = name.to_s.split(".")[-1]


    m_args = rs = $scope[0].map["#{scope.parent.name}.#{name.to_s}"]
    if m_args.is_a?(Scope)
      m_args = m_args.args
    else
      m_args=nil
    end
    
    args = "()" if (!args) || (args=='')
    args=args.gsub(/\(|\)/,'').split(",")
    i=-1
    args="("+args.map do |q| i+=1; x="#{t=m_args ? (m_args[i] ? m_args[i] : scope.map[q.strip.to_s!].to_t!) : scope.map[q.strip.to_s!].to_t!} #{q=q.to_s!.strip}";scope.map[q.to_s!.strip.split("=")[0].strip]=t unless scope.declared?(q);x; end.join(", ")+")" if args!="()"    
    args.gsub("  ", " ")

    body = body.map { |ssexp|
      process ssexp
    }

    simple = body.size <= 1

    body << "// do nothing" if body.empty?
    body = body.join("\n")
    body = body.lines.to_a[1..-2].join("\n") if
      simple && body =~ /^\Abegin/ && body =~ /^end\z/
    body = indent(fmt_body(body,exp)) unless simple && body =~ /(^|\n)rescue/

    type = :void
    ($rt = type = $return) if $return
    type = :Value if type == :var
    type = $SIG[1] if $SIG && $SIG[1]
    scope.return_type = type
    type = scope
    

    dec = ((scope).map.map do |q,t|
      t=t.to_s!
      q=q.to_s!.strip
      l=args.strip.gsub(/^\(/,'').gsub(/\)$/,'').split(",").map do |q|
        q=q.strip.to_s!.split("=")[0].split(" ")[-1]
      end

      next "" if l.index(q.to_s!.split("=")[0].strip)
      next "" if l.index(q.to_s!)
      next "" if l.index(q.to_s!.strip)
      t == 'var' ? '' : indent("#{t.to_s!} #{q};\n")
    end.join+"\n") unless scope.parent.is_a?(LocalScope)

    $SIG = nil
    $return = false
    $scope << $scope[-2] #unless $SIG2 || $DELG2
    p SCOPE: scope.name
    p SCOPE2: scope.parent.name
    push_sig(name.to_s, type) unless $PROP 
    scope.map[name.to_s] = type
    $scope.pop #unless $SIG2 || $DELG2
    type=type.to_s!
    i=-1

    scope.return_type = type

    $scope.pop 
     
    virtual = (($SIGNAL || $SIG2) && (body.gsub(/\/\/.*\n?/,"").strip!='')) 
     
    blk = " {\n#{dec}#{body}\n}"
    c = ''
    c =  "// #{exp.file}: #{exp.line}\n//\n" if (($SIG2 || $SIGNAL) && !virtual) || $DELG2
    blk = '' if (($SIG2 || $SIGNAL) && !virtual) || $DELG2
     
    r="\n#{c}#{comm}public #{static ? 'static ' : ''}#{virtual ? 'virtual ' : ''}#{($SIG2 || $SIGNAL) ? 'signal ' : ''}#{($DELEGATE || $DELG2) ? 'delegate ' : ''}#{name != $klass.to_s ? "#{type.to_t!}" : ''} #{name}#{args}#{($DELEGATE || ($SIGNAL && (body.strip==''))) ? '' : blk}".gsub(/\n\s*\n+/, "\n\n")
    $SIGNAL=$DELEGATE=false
    r
  end

  def push_sig n, t
    $scope[0].map[k="#{scope.name}."+n.to_s] = t
    p({SCOPE3: {k => t.to_s}})
  end 

  def process_defs exp # :nodoc:
    _, lhs, name, args, *body = exp
    var = [:self, :cvar, :dvar, :ivar, :gvar, :lvar].include? lhs.sexp_type

    lhs = process lhs
    lhs = "(#{lhs})" unless var

    name = "#{lhs}.#{name}"

    s = s(:defn, name, args, *body)
    s.line = exp.line
    s.file = exp.file
    s.comments = exp.comments

    process_defn s
  end

  def process_dot2(exp) # :nodoc:
    _, lhs, rhs = exp

    "(#{process lhs}:#{process rhs})"
  end

  def process_dot3(exp) # :nodoc:
    _, lhs, rhs = exp

    "(#{process lhs}...#{process rhs})"
  end

  def process_dregx exp # :nodoc:
    _, str, *rest = exp

    options = re_opt rest.pop if Integer === rest.last

    "/" << util_dthing(:dregx, s(:dregx, str, *rest)) << "/#{options}"
  end

  def process_dregx_once(exp) # :nodoc:
    process_dregx(exp) + "o"
  end

  def process_dstr(exp) # :nodoc:
    "@\"#{util_dthing(:dstr, exp)}\""
  end

  def process_dsym(exp) # :nodoc:
    ":\"#{util_dthing(:dsym, exp)}\""
  end

  def process_dxstr(exp) # :nodoc:
    "`#{util_dthing(:dxstr, exp)}`"
  end

  def process_ensure(exp) # :nodoc:
    _, body, ens = exp

    body = process body
    ens  = nil if ens == s(:nil)
    ens  = process(ens) || "// do nothing"
    ens = "begin\n#{ens}\nend\n" if ens =~ /(^|\n)rescue/

    body.sub!(/\n\s*end\z/, "")
    body = indent(body) unless body =~ /(^|\n)rescue/

    "#{body}\nensure\n#{indent ens}"
  end

  def process_evstr exp # :nodoc:
    _, x = exp

    x ? process(x) : ""
  end

  def process_false exp # :nodoc:
    "false"
  end

  def process_flip2 exp # :nodoc:
    _, lhs, rhs = exp

    "#{process lhs}..#{process rhs}"
  end

  def process_flip3 exp # :nodoc:
    _, lhs, rhs = exp

    "#{process lhs}...#{process rhs}"
  end

  def process_for exp # :nodoc:
    _, recv, iter, body = exp

    $scope << LocalScope.new($scope[-1])
    recv = process recv
    iter = process iter
    body = process(body) || "// do nothing"

    result = ["var q_#{qn=recv.to_s!.split(".")[-1].gsub(/\(.*?\)/,'')} = #{recv};\n","for (var #{iter.gsub("var ",'')}_n=0; #{iter.gsub("var ",'')}_n < q_#{qn}.length; #{iter.gsub("var ",'')}_n++) {\n"]

    result << indent("var #{iter.gsub("var ",'')} = q_#{qn}[#{iter.gsub("var ",'')}_n];")
    result << indent(fmt_body(body,exp))
    $scope.pop
    result << "}"

    result.join("\n") << "\n\n"
  end

  def process_gasgn exp # :nodoc:
    process_iasgn exp
  end

  def process_gvar exp # :nodoc:
    _, name = exp
    return "GLib.Environment.get_prgname()" if name.to_s =~ /\$0/
    return "\"#{File.expand_path(exp.file)}\"" if name.to_s =~ /\$FILENAME/
    return "#{exp.line}" if name.to_s =~ /\$LINENO/
    name.to_s
  end

  def process_hash(exp) # :nodoc:
    _, *pairs = exp

    result = pairs.each_slice(2).map { |k, v|
      if k.sexp_type == :kwsplat then
        "%s" % process(k)
      else
        t = v.sexp_type

        lhs = process k
        rhs = process v
        rhs = "(#{rhs})" unless HASH_VAL_NO_PAREN.include? t

        "%s => %s" % [lhs, rhs]
      end
    }

    result.empty? ? "{}" : "{ #{result.join(", ")} }"
  end

  def process_iasgn(exp) # :nodoc:
    _, lhs, rhs = exp

    lhs = lhs.to_s.gsub("@", 'this.')

    if rhs then
      q="#{lhs} = #{r=process(rhs).to_s!}"
      s=scope
      until !s.is_a?(LocalScope)
        s=s.parent
      end
      if t=scope.declared?(a=lhs.gsub(/^this\./,''))
      
      else
        t=s.assign(zq=scope.name+"."+a,(r),scope)
        s.fields[a]=t if b = t!=:var
        $delete << zq 
      end
      
      q
    else # part of an masgn
      lhs
    end
  end

  def process_if(exp) # :nodoc:
    
    _, c, t, f = exp
    z=c
    expand = Ruby2Ruby::ASSIGN_NODES.include? c.sexp_type

    c = process c


    c = "(#{c.chomp})" if c =~ /\n/

    if t then
      unless expand then
        if f then
        
              ($open_compacted_if ||= []) << true
            t = process t
    f = process f
    $open_compacted_if.pop
          r = "(#{c}) ? (#{t}) : (#{f})#{($open_compacted_if.length > 0) ? '' : ';'}"
          r = nil if r =~ /return/ # HACK - need contextual awareness or something
         
        else
          r = "if (#{c}) { #{t}; }"
        end
        
        return r if r and (@indent + r).size < LINE_LENGTH and r !~ /\n/
      end

      r = "if (#{c}) {\n#{indent(t)};\n"
      r << "} else {\n#{indent(f)};\n" if f
      r << "}"

      r
    elsif f
      unless expand then
        r = "if (!(#{c})) { #{f};}"
        return r if (@indent + r).size < LINE_LENGTH and r !~ /\n/
      end
      "if (!(#{c}) {\n#{indent(f)};\n}"
    else
      # empty if statement, just do it in case of side effects from condition
      "if (#{c}) {\n#{indent "// do nothing"}\n}"
    end
  end

  def process_lambda exp # :nodoc:
    ""
  end
  
  def fmt_body body, e=nil
    ee=""
    ee="//#{e.file}: #{e.line}\n" if e && true
    body=ee+body.split("\n").map do |q|
      next q+";" if (q.strip =~ / \= \{/) && (q.strip !~ /;/)
      z=if q.strip !~ /(\;$)|(\}$)/              
        if q.strip !~ /\{$/
          (q.strip=='') ? q : q+";"
        else
          q
        end
      else
        q
      end
      z.gsub(/^\s+\;/,'')
    end.join("\n") if body
  end

  def process_iter(exp) # :nodoc:
    _, iter, args, body = exp

    is_lambda = iter.sexp_type == :lambda

    iter = process iter

    $scope << $scope[-2] if ($PROP && !$PROP.empty?)# || $SIG2 || $DELG2   
    body = process body if body
    $scope.pop if ($PROP && !$PROP.empty?) #|| $SIG2 || $DELG2
    
    p scope: scope.name

    args = case
           when args == 0 then
             ""
           when is_lambda then
             " (#{process(args)[1..-2]}) => "
           else
             if iter.strip == "foreach ("
               "var #{process(args)[1..-2][0]} in #{$FE.gsub(/\.$/,'')} ) "
             else
               " #{process(args)[1..-2]}"
             end
           end

    b, e = if iter == "END" then
             %w[ { } ]
           else
             %w[ do end ]
           end

    iter.sub!(/\(\)$/, "")

    # REFACTOR: ugh
    result = []
    if is_lambda then
      result << iter
      result << args
      result << " {"
    else
      if $PROP || $SIG2 || $DELG2
        
      else
        iter << "(" if (iter !~ /\)$/) && !$FE
        result << "#{iter.gsub(/\)$/,', ')} (#{args}) => {\n" if !$FE
        result << "\n#{iter} #{args} {\n" if $FE
        result << '' if !$FE
      end
    end
    
    body = fmt_body(body.strip)
    
    if $PROP || $SIG2 || $DELG2
      q="#{iter.to_s! % t=body.strip.gsub(";",'').to_s!}".gsub("public void",'').gsub("get() {\n","\nget {").gsub("set() {\n", "\nset {").strip.split("\n")
      qq=""
      p QQQ: iter
      i=-1
      a = ($PROP || (($SIG2 || $DELG2) ? [] : nil)) 
      a.each do |q|
        push_sig q,t.to_s!
        push_sig "_"+q,t.to_s!
      end

      if q.length < 2
        if $SIG2 || $DELG2
          qq= q.join("\n")# [q[0],indent(fmt_body((q[1..-1] ||[]).map do |q| q.strip end.join("\n"))).gsub(/^\s+\;\n/m,"\n")].join("\n").gsub(/^\s+\;\n/m,"\n")
        else
          qq= [q[0],indent(fmt_body(q[1..-1].map do |q| q.strip end.join("\n"))).gsub(/^\s+\;\n/m,"\n")].join("\n").gsub(/^\s+\;\n/m,"\n")
        end
      else
        qq=[q[0],q[1],indent(fmt_body(q[2..-2].map do |q| q.strip end.join("\n"))).gsub(/^\s+\;\n/m,"\n"),q[-1]].join("\n").gsub(/^\s+\;\n/m,"\n")
      end
      $DELG2=$SIG2=$PROP = false
      return qq
    end
    
    result << if body then
                indent(" #{body.strip} ")
              else
                " "
              end
    result << "\n" if $FE
    result << "\n}"
    result << ")" if !$FE
    result << "\n" if fe=$FE
    $FE = nil
    result = result.join
    
    $return = false
    
    return result #if (fe) || result !~ /\n/ and result.size < LINE_LENGTH

    result = []

    if is_lambda then
      result << iter
      result << args
      result << " #{b}"
    else
      result << "#{iter} #{b}"
      result << args
    end

    result << "\n"
    if body then
      result << indent(body.strip)
      result << "\n" unless $PROP
    end
    result << e
    result.join
  end

  def process_ivar(exp) # :nodoc:
    _, name = exp
    name.to_s.gsub("@",'this.')
  end

  def process_kwsplat(exp)
    _, kw = exp
    "**#{process kw}"
  end

  # TODO Infer

  def process_lasgn(exp) # :nodoc:
    _, name, value = exp

    s=""
    if (t= (scope.assign(name, pv=process(value)))) == :var


     s += "var "
    end
    $gt = nil
    s += "#{name}"
    s += " = #{pv}" if value
    s
  end

  def process_lit exp # :nodoc:
    _, obj = exp
    case obj
    when Range then
      "(#{obj.inspect})"
    else
      obj.inspect
    end
  end

  def process_lvar(exp) # :nodoc:
    _, name = exp
    name.to_s
  end

  def process_masgn(exp) # :nodoc:
    # s(:masgn, s(:array, s(:lasgn, :var), ...), s(:to_ary, <val>, ...))
    # s(:iter, <call>, s(:args, s(:masgn, :a, :b)), <body>)
    parenthesize = true

    result = exp.sexp_body.map { |sexp|
      case sexp
      when Sexp then
        if sexp.sexp_type == :array then
          parenthesize = context.grep(:masgn).size > 1
          res = process sexp

          res[1..-2]
        else
          process sexp
        end
      when Symbol then
        sexp
      else
        raise "unknown masgn: #{sexp.inspect}"
      end
    }
    parenthesize ? "(#{result.join ", "})" : result.join(" = ")
  end

  def process_match exp # :nodoc:
    _, rhs = exp

    "#{process rhs}"
  end

  def process_match2 exp # :nodoc:
    # s(:match2, s(:lit, /x/), s(:str, "blah"))
    _, lhs, rhs = exp

    lhs = process lhs
    rhs = process rhs

    "#{lhs} =~ #{rhs}"
  end

  def process_match3 exp # :nodoc:
    _, rhs, lhs = exp # yes, backwards

    left_type = lhs.sexp_type
    lhs = process lhs
    rhs = process rhs

    if ASSIGN_NODES.include? left_type then
      "(#{lhs}) =~ #{rhs}"
    else
      "#{lhs} =~ #{rhs}"
    end
  end

  def process_module(exp) # :nodoc:
    if !$ns
      "#{exp.comments}iface #{util_module_or_class(exp)}"
    else
       $ns=false
      "#{util_module_or_class(exp)}"
    end
  end

  def process_next(exp) # :nodoc:
    _, rhs = exp

    val = rhs && process(rhs) # maybe push down into if and test rhs?
    if val then
      "return #{val}"
    else
      "return"
    end
  end

  def process_nil(exp) # :nodoc:
    "null"
  end

  def process_not(exp) # :nodoc:
    _, sexp = exp
    "(!#{process sexp})"
  end

  def process_nth_ref(exp) # :nodoc:
    _, n = exp
    "$#{n}qq"
  end

  # TODO: Infer

  def process_op_asgn exp # :nodoc:
    # [[:lvar, :x], [:call, nil, :z, [:lit, 1]], :y, :"||"]
    _, lhs, rhs, index, op = exp

    lhs = process lhs
    rhs = process rhs

    "#{lhs}.#{index} #{op}= #{rhs}"
  end

  def process_op_asgn1(exp) # :nodoc:
    # [[:lvar, :b], [:arglist, [:lit, 1]], :"||", [:lit, 10]]
    _, lhs, index, msg, rhs = exp

    lhs   = process lhs
    index = process index
    rhs   = process rhs

    "#{lhs}[#{index}] #{msg}= #{rhs}"
  end

  def process_op_asgn2 exp # :nodoc:
    # [[:lvar, :c], :var=, :"||", [:lit, 20]]
    _, lhs, index, msg, rhs = exp

    lhs   = process lhs
    index = index.to_s[0..-2]
    rhs   = process rhs

    "#{lhs}.#{index} #{msg}= #{rhs}"
  end

  def process_op_asgn_and(exp) # :nodoc:
    # a &&= 1
    # [[:lvar, :a], [:lasgn, :a, [:lit, 1]]]
    _, _lhs, rhs = exp
    process(rhs).sub(/\=/, "&&=")
  end

  def process_op_asgn_or(exp) # :nodoc:
    # a ||= 1
    # [[:lvar, :a], [:lasgn, :a, [:lit, 1]]]
    _, _lhs, rhs = exp
    process(rhs).sub(/\=/, "||=")
  end

  def process_or(exp) # :nodoc:
    _, lhs, rhs = exp

    "(#{process lhs} || #{process rhs})"
  end

  def process_postexe(exp) # :nodoc:
    "END"
  end

  def process_redo(exp) # :nodoc:
    "redo"
  end

  def process_resbody exp # :nodoc:
    # s(:resbody, s(:array), s(:return, s(:str, "a")))
    _, args, *body = exp

    body = body.compact.map { |sexp|
      process sexp
    }

    body << "// do nothing" if body.empty?

    name =   args.lasgn true
    name ||= args.iasgn true
    args = process(args)[1..-2]
    args = " #{args}" unless args.empty?
    args += " => #{name[1]}" if name

    "rescue#{args}\n#{indent body.join("\n")}"
  end

  def process_rescue exp # :nodoc:
    _, *rest = exp

    body = process rest.shift unless rest.first.sexp_type == :resbody
    els  = process rest.pop   unless rest.last && rest.last.sexp_type == :resbody

    body ||= "// do nothing"

    # TODO: I don't like this using method_missing, but I need to ensure tests
    simple = rest.size == 1 && rest.first.size <= 3 &&
      !rest.first.block &&
      !rest.first.return

    resbodies = rest.map { |resbody|
      _, rb_args, rb_body, *rb_rest = resbody
      simple &&= rb_args == s(:array)
      simple &&= rb_rest.empty? && rb_body && rb_body.node_type != :block
      process resbody
    }

    if els then
      "#{indent body}\n#{resbodies.join("\n")}\nelse\n#{indent els}"
    elsif simple then
      resbody = resbodies.first.sub(/\n\s*/, " ")
      "#{body} #{resbody}"
    else
      "#{indent body}\n#{resbodies.join("\n")}"
    end
  end

  def process_retry(exp) # :nodoc:
    "retry"
  end

  def process_return exp # :nodoc:
    _, rhs = exp

    unless rhs then
      "break"
    else
      rhs_type = rhs.sexp_type
      rhs = process rhs
      rhs = "(#{rhs})" if ASSIGN_NODES.include? rhs_type
      $return = scope.guess_type(rhs.gsub(/^this\./,''));
      $return = nil if ($return == :var) || $PROP
      "return #{rhs}"
    end
  end

  def process_safe_attrasgn exp # :nodoc:
    _, receiver, name, *rest = exp

    receiver = process receiver
    rhs  = rest.pop
    args = rest.pop # should be nil

    raise "dunno what to do: #{args.inspect}" if args

    name = name.to_s.sub(/=$/, "")

    if rhs && rhs != s(:arglist) then
      "#{receiver}&.#{name} = #{process rhs}"
    else
      raise "dunno what to do: #{rhs.inspect}"
    end
  end

  def process_safe_op_asgn exp # :nodoc:
    # [[:lvar, :x], [:call, nil, :z, [:lit, 1]], :y, :"||"]
    _, lhs, rhs, index, op = exp

    lhs = process lhs
    rhs = process rhs

    "#{lhs}&.#{index} #{op}= #{rhs}"
  end

  def process_safe_op_asgn2(exp) # :nodoc:
    # [[:lvar, :c], :var=, :"||", [:lit, 20]]

    _, lhs, index, msg, rhs = exp

    lhs   = process lhs
    index = index.to_s[0..-2]
    rhs   = process rhs

    "#{lhs}&.#{index} #{msg}= #{rhs}"
  end

  def process_sclass(exp) # :nodoc:
    _, recv, *block = exp

    recv = process recv
    block = indent process_block s(:block, *block)

    "class << #{recv}\n#{block}\nend"
  end

  def process_self(exp) # :nodoc:
    "this"
  end

  def process_splat(exp) # :nodoc:
    _, arg = exp
    if arg.nil? then
      "*"
    else
      "*#{process arg}"
    end
  end

  def process_str(exp) # :nodoc:
    _, s = exp
    s.dump
  end

  def process_super(exp) # :nodoc:
    _, *args = exp

    args = args.map { |arg|
      process arg
    }

    "super(#{args.join ", "})"
  end

  def process_svalue(exp) # :nodoc:
    _, *args = exp

    args.map { |arg|
      process arg
    }.join ", "
  end

  def process_to_ary exp # :nodoc:
    _, sexp = exp

    process sexp
  end

  def process_true(exp) # :nodoc:
    "true"
  end

  def process_undef(exp) # :nodoc:
    _, name = exp

    "undef #{process name}"
  end

  def process_until(exp) # :nodoc:
    cond_loop(exp, "until")
  end

  def process_valias exp # :nodoc:
    _, lhs, rhs = exp

    "alias #{lhs} #{rhs}"
  end

  def process_when exp # :nodoc:
    s(:when, s(:array, s(:lit, 1)),
      s(:call, nil, :puts, s(:str, "something")),
      s(:lasgn, :result, s(:str, "red")))

    _, lhs, *rhs = exp

    cond = process(lhs)[1..-2]

    rhs = rhs.compact.map { |sexp|
      indent process sexp
    }

    rhs << indent("// do nothing") if rhs.empty?
    rhs = rhs.join "\n"

    "when #{cond} then\n#{rhs.chomp}"
  end

  def process_while(exp) # :nodoc:
    cond_loop exp, "while"
  end

  def process_xstr(exp) # :nodoc:
    "#{process_str(exp)[1..-2]}"
  end

  def process_yield(exp) # :nodoc:
    _, *args = exp

    args = args.map { |arg|
      process arg
    }

    unless args.empty? then
      "yield(#{args.join(", ")})"
    else
      "yield"
    end
  end

  def process_zsuper(exp) # :nodoc:
    "base"
  end

  ############################################################
  # Rewriters:

  def rewrite_attrasgn exp # :nodoc:
    if context.first(2) == [:array, :masgn] then
      _, recv, msg, *args = exp

      exp = s(:call, recv, msg.to_s.chomp("=").to_sym, *args)
    end

    exp
  end

  def rewrite_call exp # :nodoc:
    _, recv, msg, *args = exp

    exp = s(:not, recv) if msg == :! && args.empty?

    exp
  end

  def rewrite_ensure exp # :nodoc:
    exp = s(:begin, exp) unless context.first == :begin
    exp
  end

  def rewrite_if exp # :nodoc:
    _, c, t, f = exp

    if c.sexp_type == :not then
      _, nc = c
      exp = s(:if, nc, f, t)
    end

    exp
  end

  def rewrite_resbody exp # :nodoc:
    _, args, *_rest = exp
    raise "no exception list in #{exp.inspect}" unless exp.size > 2 && args
    raise args.inspect if args.sexp_type != :array
    # for now, do nothing, just check and freak if we see an errant structure
    exp
  end

  def rewrite_rescue exp # :nodoc:
    complex = false
    complex ||= exp.size > 3
    complex ||= exp.resbody.block
    complex ||= exp.resbody.size > 3
    resbodies = exp.find_nodes(:resbody)
    complex ||= resbodies.any? { |n| n[1] != s(:array) }
    complex ||= resbodies.any? { |n| n.last.nil? }
    complex ||= resbodies.any? { |(_, _, body)| body and body.node_type == :block }

    handled = context.first == :ensure

    exp = s(:begin, exp) if complex unless handled

    exp
  end

  def rewrite_svalue(exp) # :nodoc:
    case exp.last.sexp_type
    when :array
      s(:svalue, *exp[1].sexp_body)
    when :splat
      exp
    else
      raise "huh: #{exp.inspect}"
    end
  end

  def rewrite_until exp # :nodoc:
    _, c, *body = exp

    if c.sexp_type == :not then
      _, nc = c
      exp = s(:while, nc, *body)
    end

    exp
  end

  def rewrite_while exp # :nodoc:
    _, c, *body = exp

    if c.sexp_type == :not then
      _, nc = c
      exp = s(:until, nc, *body)
    end

    exp
  end

  ############################################################
  # Utility Methods:

  ##
  # Generate a post-or-pre conditional loop.

  def cond_loop(exp, name)
    _, cond, body, head_controlled = exp

    cond = process cond
    body = process body

    body = indent(body).chomp if body

    code = []
    if head_controlled then
      code << "#{name} #{cond} do"
      code << body if body
      code << "end"
    else
      code << "begin"
      code << body if body
      code << "end #{name} #{cond}"
    end

    code.join("\n")
  end

  ##
  # Utility method to escape something interpolated.

  def dthing_escape type, lit
    # TODO: this needs more testing
    case type
    when :dregx then
      lit.gsub(/(\A|[^\\])\//, '\1\/')
    when :dstr, :dsym then
      lit.dump[1..-2]
    when :dxstr then
      lit.gsub(/`/, '\`')
    else
      raise "unsupported type #{type.inspect}"
    end
  end

  ##
  # Indent all lines of +s+ to the current indent level.

  def indent s
    s.to_s.split(/\n/).map{|line| @indent + line}.join("\n")
  end

  ##
  # Wrap appropriate expressions in matching parens.

  def parenthesize exp
    case context[1]
    when nil, :defn, :defs, :class, :sclass, :iter, :if, :resbody, :when, :while then
      "#{exp}"
    else
      "(#{exp})"
    end
  end

  ##
  # Return the appropriate regexp flags for a given numeric code.

  def re_opt options
    bits = (0..8).map { |n| options[n] * 2**n }
    bits.delete 0
    bits.map { |n| Regexp::CODES[n] }.join
  end

  ##
  # Return a splatted symbol for +sym+.

  def splat(sym)
    :"*#{sym}"
  end

  ##
  # Utility method to generate something interpolated.

  def util_dthing(type, exp)
    _, str, *rest = exp

    # first item in sexp is a string literal
    str = dthing_escape(type, str)

    rest = rest.map { |pt|
      case pt.sexp_type
      when :str then
        dthing_escape(type, pt.last)
      when :evstr then
        '$(%s.to_string())' % [process(pt)]
      else
        raise "unknown type: #{pt.inspect}"
      end
    }

    [str, rest].join
  end

  ##
  # Utility method to generate ether a module or class.

  def util_module_or_class exp, is_class = false
    $scope << Scope.new(scope)
    
    result = []

    _, name, *body = exp
    superk = body.shift if is_class

    name = process name if Sexp === name
    $klass = name if is_class
    
    scope.name = name.to_s.gsub(/^\./,'')
    
    scope.parent.map[name.to_s] = scope
    

    
    result << name
    result << "<#{$generics.join(", ")}>" if $klass && $generics

    if superk then
      superk = process superk
      result << " : #{superk}" if superk
      scope.superclass = superk if superk
    end

    result << " {\n"

    body = body.map { |sexp|
      process(sexp).chomp
    }

    body = unless body.empty? then
             indent(fmt_body(body.find_all do |q| q end.map do |q| (q.strip =~ /^\}$/) ? q+"\n" : q end.join("\n"))) + "\n"
           else
             ""
           end
    unless scope.fields.empty?
      result << indent("// Fields set to infered type via @<var> assignment!\n")+"\n"
    
      scope.fields.each do |k,v|
        pri = (k.to_s! =~ /^\_/)
        result << indent("#{pri ? "private" : "public"} #{v} #{k};\n")+"\n"
      end
      result << indent("// END infered @<var>\n\n")+"\n\n"
    end

    result << body
    result << "}"
    $generics = nil
    $klass=nil
    $scope.pop
    result.join
  end
end
