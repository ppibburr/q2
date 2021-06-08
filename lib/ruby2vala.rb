#!/usr/bin/env ruby -w

require "rubygems"
require "sexp_processor"

class Scope
  attr_reader :map, :parent
  attr_accessor :name
  def initialize p=nil
    @parent=p
    @map={}
    @name=''
  end  
  
  def declared? q
    q=q.to_s.gsub(/\(.*?\)/,'') if q

    z=self.map[q] || (parent ? parent.declared?(q) : nil)

    return z if q =~ /\./

    z || (("#{self.name}.#{q}" != q) ? declared?("#{self.name}.#{q}") : nil)
  end
  
  def assign q, what
    q=q.to_s
    unless declared?(q)
      qq=if t=declared?(what)  
        t
      else
        case what
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
      
      self.map[q] = qq
    end
  end
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

    # self.debug[:defn] = /zsuper/
  end

  ############################################################
  # Processors

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

  def process_block exp # :nodoc:
    _, *body = exp

    result = body.map { |sexp|
      process sexp
    }

    result << "// do nothing\n" if result.empty?
    result = parenthesize result.join "\n"
    result += "\n" unless result.start_with? "("

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
  end

  def process_call(exp, safe_call = false) # :nodoc:
    _, recv, name, *args = exp

    aa = nil

    receiver_node_type = recv && recv.sexp_type
    receiver = process recv
    receiver = "(#{receiver})" if ASSIGN_NODES.include? receiver_node_type

    # args = []

    # this allows us to do both old and new sexp forms:
    # exp.push(*exp.pop[1..-1]) if exp.size == 1 && exp.first.first == :arglist
    
    @calls.push name

    in_context :arglist do
      max = args.size - 1
      args = args.map.with_index { |arg, i|
        arg_type = arg.sexp_type
        is_empty_hash = arg == s(:hash)
        arg = process arg

        next if arg.empty?

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

    case name
    when *BINARY then
      if safe_call
        "#{receiver}&.#{name}(#{args.join(", ")})"
      elsif args.length > 1
        "#{receiver}.#{name}(#{args.join(", ")})"
      else
        "(#{receiver} #{name} #{args.join(", ")})"
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
          args="(#{n_args.join}.to_string()+\"\\n\")"
        else
          n_args[0] = n_args[0].to_s+'+"\n"'
          args="(#{n_args.join(',')})"
        end
      end

      if receiver.to_s=="."
        receiver = ""
      end

      if name.to_s == 'each'
        $FE = receiver
        ("foreach (")
      elsif (name.to_s == "class") && (receiver.to_s.gsub(/\.$/,'') == 'this')
        ""
      elsif name.to_s == "new"
        "new #{receiver.to_s.gsub(/\.$/,'')}#{args}"
      elsif name.to_s == "GenericType"
        "#{n_args[0]}<#{n_args[1..-1].join(",")}>"
      elsif name.to_s == 'sig'

        $SIGNAL = true
        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        ""
      elsif name.to_s == 'dele'

        $DELEGATE = true
        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        ""
      elsif name.to_s == 'defn'

        $SIG = [n_args[0].gsub(/\{|\}/,'').split(",").map do |q| q.strip.to_s! end, n_args[1]]
        
        ""
      elsif name.to_s == "property"
        $PROP = true
        "public #{n_args[1].to_s!} _#{n_args[0].to_s!};"+
        ("public #{n_args[1].to_s!} #{n_args[0].to_s!} {\n %s \n}")
       
      elsif name.to_s == "attr_accessor"
        $PROP = true
        n_args.map do |a|
          ("public %s #{a.to_s!} { get; set; }")
        end.join("\n")
      elsif name.to_s == "attr_reader"
        $PROP = true
        n_args.map do |a|
          ("public %s #{a.to_s!} { get; }")
        end.join("\n")
      elsif name.to_s == "attr_writer"
        $PROP = true
        n_args.map do |a|
          ("public %s #{a.to_s!} { set; }")
        end.join("\n")        
      else
      
        args = "()" if (args == '') || !args
        "#{receiver}#{name}#{aa ? '()' : args}"
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
    "#{exp.comments}public class #{util_module_or_class(exp, true)}"
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

    name.to_s
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

    comm = exp.comments
    args = process args
    args = "" if args == "()"

    if $SIG
      args.gsub(/(^\()|(\)$)/,'').split(",").each_with_index do |q,i|
        scope.map[q.to_s.strip.to_s!] = $SIG[0][i].to_s! 
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


    body = body.map { |ssexp|
      process ssexp
    }

    simple = body.size <= 1

    body << "// do nothing" if body.empty?
    body = body.join("\n")
    body = body.lines.to_a[1..-2].join("\n") if
      simple && body =~ /^\Abegin/ && body =~ /^end\z/
    body = indent(fmt_body(body)) unless simple && body =~ /(^|\n)rescue/


     
    dec = scope.map.map do |q,t|
      l=args.gsub(/\(|\)/,'').split(",").map do |q|
        q.strip.to_s!
      end
      next "" if l.index(q)
      t == :var ? '' : indent("#{t} #{q};\n")
    end.join+"\n"
     
    type = :void
    type = $return if $return
    type = :Value if type == :var
    type = $SIG[1] if $SIG && $SIG[1]

    $SIG = nil
    $return = false
    $scope[0].map[scope.parent.name+"."+name.to_s] = type
    
    i=-1
    args = "()" if (!args) || (args=='')
    args="("+args.gsub(/\(|\)/,'').split(",").map do |q| i+=1; "#{scope.map[q.strip.to_s!]} #{q}" end.join(", ")+")" if args!="()"

    $scope.pop
     
    virtual = ($SIGNAL && (body.strip!='')) 
     
    r="#{comm}public #{static ? 'static ' : ''}#{virtual ? 'virtual ' : ''}#{$SIGNAL ? 'signal ' : ''}#{$DELEGATE ? 'delegate ' : ''}#{name != $klass.to_s ? "#{type}" : ''} #{name}#{args}#{($DELEGATE || ($SIGNAL && (body.strip==''))) ? '' : " {\n#{dec}#{body}\n}"}".gsub(/\n\s*\n+/, "\n")
    $SIGNAL=$DELEGATE=false
    r
  end

  def process_defs exp # :nodoc:
    _, lhs, name, args, *body = exp
    var = [:self, :cvar, :dvar, :ivar, :gvar, :lvar].include? lhs.sexp_type

    lhs = process lhs
    lhs = "(#{lhs})" unless var

    name = "#{lhs}.#{name}"

    process_defn s(:defn, name, args, *body)
  end

  def process_dot2(exp) # :nodoc:
    _, lhs, rhs = exp

    "(#{process lhs}..#{process rhs})"
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
    "\"#{util_dthing(:dstr, exp)}\""
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

    result = ["for (#{iter}_n=0; #{iter.gsub("var ",'')}_n < #{recv}.length; #{iter.gsub("var ",'')}_n++) {"]

    result << indent("#{iter} = #{recv}[#{iter.gsub("var ",'')}_n];")
    result << indent(fmt_body(body))
    $scope.pop
    result << "}"

    result.join "\n"
  end

  def process_gasgn exp # :nodoc:
    process_iasgn exp
  end

  def process_gvar exp # :nodoc:
    _, name = exp

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

    if rhs then
      "#{lhs} = #{process rhs}"
    else # part of an masgn
      lhs.to_s
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
  
  def fmt_body body
    body=body.split("\n").map do |q|
      next q+";" if (q.strip =~ / \= \{/) && (q.strip !~ /(\;$)/)
      if q.strip !~ /(\;$)|(\}$)/              
        if q.strip !~ /\{$/
          q=='' ? q : q+";"
        else
          q
        end
      else
        q
      end
    end.join("\n") if body
  end

  def process_iter(exp) # :nodoc:
    _, iter, args, body = exp

    is_lambda = iter.sexp_type == :lambda

    iter = process iter
    body = process body if body

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
      if $PROP
        
      else
        iter << "(" if (iter !~ /\)$/) && !$FE
        result << "#{iter.gsub(/\)$/,', ')} (#{args}) => {" if !$FE
        result << "#{iter} #{args} {" if $FE
        result << '' if !$FE
      end
    end
    
    body = fmt_body(body)
    
    if $PROP
      $PROP = false
      return "#{iter.to_s! % body.strip.gsub(";",'').to_s!}".gsub("public void",'').gsub("get() {","get {").gsub("set() {", "set {")
    end
    
    result << if body then
                " #{body.strip} "
              else
                " "
              end
    result << "}"
    result << ")" if !$FE
    $FE = nil
    result = result.join
    
    $return = false
    
    return result if result !~ /\n/ and result.size < LINE_LENGTH

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
      result << "\n"
    end
    result << e
    result.join
  end

  def process_ivar(exp) # :nodoc:
    _, name = exp
    name.to_s
  end

  def process_kwsplat(exp)
    _, kw = exp
    "**#{process kw}"
  end

  # TODO Infer

  def process_lasgn(exp) # :nodoc:
    _, name, value = exp

    s=""
    if (t=scope.assign(name, pv=process(value))) == :var
     s += "var "
    end

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
    "#{exp.comments}iface #{util_module_or_class(exp)}"
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
    "$#{n}"
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
      $return = scope.declared?(rhs);
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
        '#{%s}' % [process(pt)]
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
    result << name

    if superk then
      superk = process superk
      result << " : #{superk}" if superk
    end

    result << " {\n"

    body = body.map { |sexp|
      process(sexp).chomp
    }

    body = unless body.empty? then
             indent(fmt_body(body.find_all do |q| q.strip !='' end.join("\n\n"))) + "\n"
           else
             ""
           end

    result << body
    result << "}"

    $scope.pop
    result.join
  end
end
