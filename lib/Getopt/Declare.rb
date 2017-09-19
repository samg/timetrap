#
#  Getopt::Declare - Declaratively Expressed Command-Line Arguments via Regular Expressions
#
#  Ruby port of Perl's Getopt::Declare, version 1.21, 
#  released May 21, 1999.
#
#   	$Release Version: 1.28 $
#       $Date: 2007/01/15 10:53:09 $
#   	by Gonzalo Garramuño
#
#  For detailed instructions, see Declare.rdoc file
#
#  Ruby Port:
#         Copyright (c) 2004, Gonzalo Garramuno. All Rights Reserved.
#       This package is free software. It may be used, redistributed
#       and/or modified under the terms of the Perl Artistic License
#            (see http://www.perl.com/perl/misc/Artistic.html)
#
#  Original Perl Implementation:
#  Damian Conway (damian@conway.org)
#         Copyright (c) 1997-2000, Damian Conway. All Rights Reserved.
#       This package is free software. It may be used, redistributed
#       and/or modified under the terms of the Perl Artistic License
#            (see http://www.perl.com/perl/misc/Artistic.html)
#

require File.expand_path(File.join(File.dirname(__FILE__), "DelimScanner"))


# Verifies that code is valid Ruby code.  returns false if not
def valid_syntax?(code, fname = 'parser_code')
  eval("BEGIN {return true}\n#{code}", nil, fname, 0)
rescue Exception
  false
end


# An add-on to the String class
class String
  # Expand all tabs to spaces
  def expand_tabs!( tabstop = 8 )
    while self.sub!(/(^|\n)([^\t\n]*)(\t+)/sex) { |f|
	val = ( tabstop * "#$3".length() - ("#$2".length() % tabstop) )
	"#$1#$2" + (" " * val)
      }
    end
    self
  end

  # Return new string with all tabs set to spaces
  def expand_tabs( tabstop = 8 )
    h = self.dup
    while h.sub!(/(^|\n)([^\t\n]*)(\t+)/sex) { |f|
	val = ( tabstop * "#$3".length() - ("#$2".length() % tabstop) )
	"#$1#$2" + (" " * val)
      }
    end
    h
  end
end


# Regex for removing bracket directives
BracketDirectives = 
  /\[\s*(?:ditto|tight|strict|no\s*case|repeatable|debug|required|mutex:.*|implies:.*|excludes:.*|requires:.*|cluster:.*)\s*\]/


module Getopt

  # Main Class
  class Declare

    VERSION = '1.28'

    # For debugging, use [debug] and it will output the ruby code as .CODE.rb
    @@debug = false

    # Main separator used to distinguish arguments in Getopt/Declare spec.
    # By default, one or more tabs or 3 spaces or more.
    @@separator = '(?:\t+| {3}[^<])'

    # Class used to handle the beginning of options
    class StartOpt

      # Returns regex used matching start of options
      def matcher(g)
	'(?:()'
      end

      # Returns code used
      def code(*t)
	''
      end

      # Returns how to cache code in class
      def cachecode(a,b)  
	''
      end

      # Helps build regex that matches parameters of flags 
      def trailer    
	nil
      end

     # Helps build regex that matches parameters of flags 
      def ows(g)	      
	g
      end
    end # StartOpt


    # Class used to handle the ending of options
    class EndOpt < StartOpt
      # Returns regex used matching end of options
      def matcher(g)
	'())?' 
      end
    end  # EndOpt


    # Class used to handle scalar (ie.non-array) parameters
    class ScalarArg

      @@stdtype = {}

      # (re)set standard types
      def ScalarArg._reset_stdtype
	@@stdtype = {
	  ':i'	=> { :pattern => '(?:(?:%T[+-]?)%D+)' },
	  ':n'	=> { :pattern => '(?:(?:%T[+-]?)(?:%D+(?:%T\.%D*)?' +
	    '(?:%T[eE](?:[+-])?%D+)?|%T\.%D+(?:%T[eE](?:[+-])?%D+)?))',
	  },
          ':s'	=> { :pattern => '(?:%T(?:\S|\0))+(?=\s|\0|\z)' },
          ':qs'	=> { :pattern => %q{"(?:\\"|[^"])*"|'(?:\\'|[^'])*'|(?:%T(?:\S|\0))+} },
	  ':id'	=> { :pattern => '%T[a-zA-Z_](?:%T\w)*(?=\s|\0|\z)' },
	  ':d'	=> { 
            :pattern => '(?:%T(?:\S|\0))+',
	    :action => %q%
              reject( (_VAL_.nil? || !test(?d, _VAL_) ),
               "in parameter '#{_PARAM_}' (\"#{_VAL_}\" is not a directory)")%
	  },
	  ':if'	=> { 
            :pattern => '%F(?:%T(?:\S|\0))+(?=\s|\0|\z)',
	    :action => %q%
              reject( (_VAL_.nil? || _VAL_ != "-" && !test(?r, _VAL_) ),
               "in parameter '#{_PARAM_}' (file \"#{_VAL_}\" is not readable)")%
	  },
	  ':of'	=> { 
            :pattern => '%F(?:%T(?:\S|\0))+(?=\s|\0|\z)',
	    :action => %q%
            reject( (_VAL_.nil? || _VAL_ != "-" && 
                     test(?r, _VAL_) && !test(?w, _VAL_)), 
              "in parameter '#{_PARAM_}' (file \"#{_VAL_}\" is not writable)")%
	  },
	  ''	=> { :pattern => ':s', :ind => 1 },

	  ':+i'	=> { 
            :pattern => ':i',
	    :action => %q%reject( _VAL_ <= 0, 
                                   "in parameter '#{_PARAM_}' (#{_VAL_} must be an integer greater than zero)")%,
	    :ind => 1
	  },

	  ':+n'	=> { 
            :pattern => ':n',
	    :action => %q%reject( _VAL_ <= 0.0, 
                                   "in parameter '#{_PARAM_}' (#{_VAL_} must be a number greater than zero)")%,
	    :ind => 1
	  },

	  ':0+i' => { 
            :pattern => ':i',
	    :action => %q%reject( _VAL_ < 0, 
                                   "in parameter '#{_PARAM_}' (#{_VAL_} must be an positive integer)")%,
	    :ind  => 1
	  },
	  
	  ':0+n' => { 
	    :pattern => ':n',
	    :action => %q%reject( _VAL_ < 0, 
                                   "in parameter '#{_PARAM_}' (#{_VAL_} must be an positive number)")%,
	    :ind => 1
	  },
	}

      end # _reset_stdtype


      # Given a standard type name, return the corresponding regex
      # pattern or nil
      def ScalarArg.stdtype(name)
	seen = {}
	while (!seen[name] && @@stdtype[name] && @@stdtype[name][:ind])
	  seen[name] = 1; name = @@stdtype[name][:pattern]
	end

	return nil if seen[name] || !@@stdtype[name]
	@@stdtype[name][:pattern]
      end

      def stdtype(name)
	ScalarArg.stdtype(name)
      end


      # Given the name of a type, return its corresponding action(s)
      def ScalarArg.stdactions(name)
	seen = {}
	actions = []
	while (!seen[name] && @@stdtype[name] && @@stdtype[name][:ind])
	  seen[name] = 1
	  if @@stdtype[name][:action]
	    actions.push( @@stdtype[name][:action] )
	  end
	  name = @@stdtype[name][:pattern]
	end

	if @@stdtype[name] && @@stdtype[name][:action]
	  actions.push( @@stdtype[name][:action] )
	end

	return actions
      end

      # Add a new (user defined) type to the standard types
      def ScalarArg.addtype(abbrev, pattern, action, ref)

	typeid = ":#{abbrev}"
	unless (pattern =~ /\S/)
	  pattern = ":s"
	  ref = 1
	end
	
	@@stdtype[typeid] = {}
	@@stdtype[typeid][:pattern] = "(?:#{pattern})" if pattern && !ref
	@@stdtype[typeid][:pattern] = ":#{pattern}" if pattern && ref
	@@stdtype[typeid][:action]  = action if action
	@@stdtype[typeid][:ind]     = ref

      end

      attr :name
      attr :type
      attr :nows


      # Constructor
      def initialize(name, type, nows)
	@name = name
	@type = type
	@nows = nows
      end

      # Create regexp to match parameter
      def matcher(g)
	trailing = g ? '(?!'+Regexp::quote(g)+')' : ''

	# Find type in list of standard (and user) types
	stdtype = stdtype(@type)

	# Handle stdtypes that are specified as regex in parameter
	if (!stdtype && @type =~ %r"\A:/([^/]+)/\Z" )
	  stdtype = "#$1"
	end

	if stdtype.nil?
	  raise "Error: bad type in Getopt::Declare parameter variable specification near '<#{@name}#{@type}>'\nValid types are:\n" + @@stdtype.keys.inspect
	end

	stdtype = stdtype.dup  # make a copy, as we'll change it in place
	stdtype.gsub!(/\%D/,"(?:#{trailing}\\d)")
	stdtype.gsub!(/\%T/,trailing)
	unless ( stdtype.sub!("\%F","") )
	  stdtype = Getopt::Declare::Arg::negflagpat + stdtype
	end
	return "(?:#{stdtype})"
      end

      # Return string with code to process parameter
      def code(*t)
	if t[0]
	  pos1 = t[0].to_s
	else
	  pos1 = '0'
	end

	c = conversion
	c = "\n	          _VAL_ = _VAL_#{c} if _VAL_" if c

	code = <<-EOS
	          _VAR_ = %q|<#{@name}>|
	          _VAL_ = @@m[#{pos1}]
	          _VAL_.tr!("\\0"," ") if _VAL_#{c}
EOS

        actions = Getopt::Declare::ScalarArg::stdactions(@type)

	  for i in actions
	    next if i.nil?
	    # i.sub!(/(\s*\{)/, '\1 module '+t[1])
	    code << "
		  begin
                        #{i}
		  end
"
	  end

	code << "		  #{@name} = _VAL_\n"
     end

     # Based on parameter type, default conversion to apply
     def conversion
       pat = @@stdtype[@type] ? @@stdtype[@type][:pattern] : ''
       [ @type, pat ].each { |t|
	 case t
	 when /^\:0?(\+)?i$/
	   return '.to_i'
	 when /^\:0?(\+)?n$/
	   return '.to_f'
	 end
       }
       return nil
     end

     # Return string with code to cache argument in Getopt::Declare's cache
     def cachecode(ownerflag, itemcount)
       if itemcount > 1
	 "		  @cache['#{ownerflag}']['<#{@name}>'] = #{@name}\n"
       else
	 "		  @cache['#{ownerflag}'] = #{@name}\n"
       end
     end

     # Helps build regex that matches parameters of flags 
     def trailer 
       nil	# MEANS TRAILING PARAMETER VARIABLE (in Perl,was '')
     end
     
     # Helps build regex that matches parameters of flags 
     # Wraps parameter passed for #$1, etc. matching
     def ows(g)
       return '[\s|\0]*(' + g + ')' unless @nows
       '('+ g +')'
     end

   end  # ScalarArg


   # Class used to handle array arguments
   class ArrayArg < ScalarArg

     # Create regexp to match array
     def matcher(g)
       suffix = !g.nil? ? '([\s\0]+)' : ''
       scalar = super  # contains regex to match a scalar element
       # we match one obligatory element, and one or more optionals ')*'
       return scalar + '(?:[\s\0]+' + scalar + ')*' + suffix
     end

     # Return string with code to process array parameter
     def code(*t)
	
	if t[0]
	  pos1 = t[0].to_s
	else
	  pos1 = '0'
	end

	code = <<-EOS
		  _VAR_ = %q|<#{@name}>|
		  _VAL_ = nil
		  #{@name} = (@@m[#{pos1}]||'').split(' ').map { |i| 
                                                           i.tr("\\0", " ") }
	EOS

       # Handle conversion to proper type
       c = conversion
       if c
	 code << "		  #{@name}.map! { |i| i#{c} }\n"
       end

       actions = Getopt::Declare::ScalarArg::stdactions(@type)
       if actions.size > 0
	 code << "		  for _VAL_ in #{@name}\n"
	 for i in actions
	    code << "		       #{i}\n"
	 end
	 code << "		  end\n\n"
       end
       return code
     end

     # Return string with code to cache array in Getopt::Declare's cache
     def cachecode(ownerflag, itemcount)
       if itemcount > 1
	 "		  @cache['#{ownerflag}']['<#{@name}>'] = [] unless @cache['#{ownerflag}']['<#{@name}>']
		  @cache['#{ownerflag}']['<#{@name}>'] = #{@name}\n"
       else
	 "		  @cache['#{ownerflag}'] = #{@name}\n"
       end
     end
   end # ArrayArg


   # Class used to handle punctuations (., -, etc.)
   class Punctuator

     # Constructor
     def initialize(text, nows)	
       @text = text
       @nows = nows
     end

     # Return regex that matches this punctuation
     def matcher(g)
       Arg::negflagpat + Regexp::quote(@text)
     end

     # Return string with code to process punctuation
     def code(*t)
       
       if t[0]
	 pos1 = t[0].to_s
       else
	 pos1 = '0'
       end
       "                  if @@m[#{pos1}] && !@@m[#{pos1}].empty?
                    _PUNCT_['#{@text}'] = @@m[#{pos1}]
                  end
"
     end

     # Return string with code to cache punctuation in Getopt::Declare's cache
     def cachecode(ownerflag, itemcount)
       if itemcount > 1
	 "                  @cache['#{ownerflag}']['#{@text}'] = _PUNCT_['#{@text}']\n"
       else
         "                  unless @cache['#{ownerflag}']\n" +
         "                    @cache['#{ownerflag}'] = _PUNCT_['#{@text}'] || 1\n" +
         "                   end\n"
       end
     end

     # Helps build regex that matches parameters of flags 
     def trailer 
       @text
     end

     # Helps build regex that matches parameters of flags 
     # Wraps parameter passed for #$1, etc. matching
     def ows(g)
       return '[\s\0]*(' + g + ')' unless @nows
       '(' + g + ')'
     end #ows

   end # Punctuator


  # Class used to handle other arguments (flags, etc)
  class Arg

    @@nextid = 0


    Helpcmd  = %w( -help --help -Help --Help -HELP --HELP -h -H )

    @@helpcmdH = {}
    for i in Helpcmd; @@helpcmdH[i] = 1; end

    def Arg.besthelp
      for i in Helpcmd; return i if @@helpcmdH[i]; end
    end

    # Create regex of help flags based on help shortcuts left
    def Arg.helppat
      @@helpcmdH.keys.join('|')
    end


    Versioncmd = %w( -version --version -Version --Version
		     -VERSION --VERSION -v -V )
    @@versioncmdH = {}
    for i in Versioncmd; @@versioncmdH[i] = 1; end

    def Arg.bestversion
      for i in Versioncmd; return i if @@versioncmdH[i]; end
    end

    # Create regex of version flags based on help shortcuts left
    def Arg.versionpat
      @@versioncmdH.keys.join('|')
    end

    @@flags = []
    @@posflagpat = nil
    @@negflagpat = nil

    def Arg.clear
      @@flags = []
      @@nextid = 0
      @@posflagpat  = nil
      @@negflagpath = nil
    end

    # Return string with regex that avoids all flags in declaration
    def Arg.negflagpat(*t)
      if !@@negflagpat && @@flags
	@@negflagpat = ( @@flags.map { |i| 
			  "(?!" + Regexp::quote(i) + ")" } ).join('')
      else
	@@negflagpat
      end
    end

    # Return string with regex that matches any of the flags in declaration
    def Arg.posflagpat(*t)
      if !@@posflagpat && @@flags
	@@posflagpat = '(?:' + ( @@flags.map { |i| 
				  Regexp::quote(i) } ).join('|') + ')'
      else
	@@posflagpat
      end
    end

    attr_accessor :flag, :args, :actions, :ditto, :nocase
    attr_accessor :required, :id, :repeatable, :desc
    attr_accessor :requires


    #
    def found_requires
      expr = @requires.gsub(/((?:&&|\|\|)?\s*(?:[!(]\s*)*)([^ \t\n|&\)]+)/x,
                            '\1_FOUND_[\'\2\']')
      
      if !valid_syntax?( expr )
        raise "Error: bad condition in [requires: #{original}]\n"
      end
      expr
    end


    # Constructor
    def initialize(spec, desc, dittoflag)
      first = 1


      @@nextid += 1
      @flag 	= ''
      @foundid  = nil
      @args	= []
      @actions  = []
      @ditto	= dittoflag
      @required = false
      @requires = nil
      @id       = @@nextid
      @desc	= spec.dup
      @items	= 0
      @nocase   = false

      @desc.sub!(/\A\s*(.*?)\s*\Z/,'\1')

      while spec && spec != ''
	begin

	  # OPTIONAL
	  if spec.sub!( /\A(\s*)\[/, '\1' )
	    @args.push( StartOpt.new )
	    next
	  elsif spec.sub!(/\A\s*\]/,"")
	    @args.push( EndOpt.new )
	    next
	  end

	  # ARG

	  se  = DelimScanner::new( spec )
	  tmp = se.scanBracketed('<>')

	  arg = nows = nil
	  arg, spec, nows = tmp[:match], tmp[:suffix], tmp[:prefix] if tmp


	  if arg
	    arg =~ /\A(\s*)(<)([a-zA-Z]\w*)(:[^>]+|)>/ or
	      raise "Error: bad Getopt::Declare parameter variable specification near '#{arg}'\n"

            # NAME,TYPE,NOW
	    details = [ "#$3", "#$4", !first && !(nows.length>0) ]

	    if spec && spec.sub!( /\A\.\.\./, "")	# ARRAY ARG
	      @args.push( ArrayArg.new(*details) )
	    else  # SCALAR ARG
	      @args.push( ScalarArg.new(*details) )
	    end
	    @items += 1
	    next

	    # PUNCTUATION
	  elsif spec.sub!( /\A(\s*)((\\.|[^\] \t\n\[<])+)/, '' )
	    ows, punct = $1, $2
	    punct.gsub!( /\\(?!\\)(.)/, '\1' )

	    if first
              spec  =~ /\A(\S+)/
              @foundid = "#{punct}#{$1}"
	      @flag = punct
	      @@flags.push( punct )
	    else
	      @args.push( Punctuator.new(punct, !(ows.size > 0)) )
	      @items += 1
	    end

	  else 
	    break
	  end # if arg/spec.sub
	ensure
	  first = nil
	end
      end # while

      @@helpcmdH.delete(@flag)    if @@helpcmdH.key?(@flag)
      @@versioncmdH.delete(@flag) if @@versioncmdH.key?(@flag)
    end # initialize



    # Return String with code to parse this argument (ie. flag)
    def code(*t)
      owner = t[0]
      mod   = t[1]


      code = "\n"
      flag = @flag
      clump = owner.clump
      i = 0
      nocasei = ((Getopt::Declare::nocase || @nocase) ? 'i' : '')

      code << "          catch(:paramout) do\n            while "
      code += !@repeatable? "!_FOUND_['" + self.foundid + "']" : "true"

      if (flag && (clump==1 && flag !~ /\A[^a-z0-9]+[a-z0-9]\Z/i ||
		   (clump<3 && @args.size > 0 )))
	code << ' and !_lastprefix'
      end

      code <<'
              begin
                catch(:param) do
                  _pos = _nextpos if _args
                  _PUNCT_ = {}
             '

      if flag != ''
        # This boundary is to handle -- option, so that if user uses
        # --foo and --foo is not a flag, it does not become
        # --  and unused: 'foo', but an error saying flag '--foo' not defined.
        boundary = ''
        boundary = '(\s+|\Z)' if flag =~ /^(--|-|\+|\+\+)$/

	code << '
                  _args && _pos = gindex( _args, /\G[\s|\0]*' + 
	  Regexp::quote(flag) + boundary + '/' + nocasei + ", _pos) or throw(:paramout) 
                  unless @_errormsg
		    @_errormsg = %q|incorrect specification of '" + flag + "' parameter|
                  end
"
      elsif ( ScalarArg::stdtype(@args[0].type)||'') !~ /\%F/
	code << "\n                  throw(:paramout) if @_errormsg\n"
      end


      code << "\n                  _PARAM_ = '" + self.name + "'\n"


      trailer = []
      i = @args.size-1
      while i > 0
	trailer[i-1] = @args[i].trailer
	trailer[i-1] = trailer[i] unless trailer[i-1]
	i -= 1
      end # while i

      if @args
	code << "\n"+'                 _args && _pos = gindex( _args, /\G'

	@args.each_with_index { |arg, i|
	  code << arg.ows(arg.matcher(trailer[i]))
	}

	code << '/x' + nocasei + ", _pos ) or throw(:paramout)\n"
      end # if @args

      @args.each_with_index { |arg, i|
	code << arg.code(i,mod)	#, $flag ????
      }

      if flag
	mutexlist = owner.mutex[flag] ? 
	(  owner.mutex[flag].map {|i| "'#{i}'"} ).join(',') : ''

	code << "
                  if _invalid.has_key?('#{flag}')
                    @_errormsg = %q|parameter '#{flag}' not allowed with parameter '| + _invalid['#{flag}'] + %q|'|
                    throw(:paramout)
                  else
		    for i in [#{mutexlist}]
		        _invalid[i] = '#{flag}'
                    end
                  end  #if/then

"
      end



      for action in @actions
	#action.sub!( /(\s*\{)/, '\1 module '+mod )  # @TODO
	code << "\n                  " + action + "\n"
      end

      if flag && @items==0
	code << "\n                  @cache['#{flag}'] = '#{flag}'\n"
        if @ditto
          code << "\n                  @cache['#{@ditto.flag}'] = '#{flag}'\n"
        end
      end

      if @items > 1
	code << "                  @cache['#{self.name}'] = {} unless @cache['#{self.name}'].kind_of?(Hash)\n"
        if @ditto
          code << "\n                  @cache['#{@ditto.name}'] = {} unless @cache['#{@ditto.name}'].kind_of?(Hash)\n"
        end
      end

      for subarg in @args
	code << subarg.cachecode(self.name,@items)
        if ditto
	code << subarg.cachecode(@ditto.name,@items)
        end
      end

      if flag =~ /\A([^a-z0-9]+)/i
	code << '                  _lastprefix = "'+ Regexp::quote("#$1") + '"' + "\n"
      else
	code << "                  _lastprefix = nil\n"
      end

      code << "
                  _FOUND_['"+ self.foundid + "'] = 1
                  throw :arg if _pos > 0
		  _nextpos = _args.size
                  throw :alldone
                end  # catch(:param)
	      end  # begin
            end # while
          end # catch(:paramout)
"

      code
    end

    # Return name of argument, which can be flag's name or variable's name
    def name
      return @flag unless @flag.empty?
      for i in @args
        return "<#{i.name}>" if i.respond_to?(:name)
      end
      raise "Unknown flag name for parameter #{self.desc}"
    end

    # Return foundid of argument, which can be flag's name or variable's name
    def foundid
      return @foundid || self.name
    end

  end # Arg


  private

  class << self
    @nocase = false
    attr_accessor :nocase
  end

  #
  # This is an additional function added to the class to simulate Perl's
  # pos() \G behavior and m///g
  #
  # It performs a regex match, and returns the last index position of the 
  # match or nil.  On successive invocations, it allows doing regex matches
  # NOT from the beginning of the string easily.
  #
  # Class Array @@m stores the list of matches, as #$1 and similar 
  # variables have short lifespan in ruby, unlike perl.
  #
  def gindex(str, re, pos)
    @@m.clear()
    if pos = str.index( re, pos )
      l = $&.size  # length of match
      if l > 0
	@@m[0] = "#$1"
	@@m[1] = "#$2"
	@@m[2] = "#$3"
	@@m[3] = "#$4"
	@@m[4] = "#$5"
	@@m[5] = "#$6"
	@@m[6] = "#$7"
	@@m[7] = "#$8"
	@@m[8] = "#$9"
	pos += l
      end
    end
    pos
  end

  # Given an array or hash, flatten them to a string
  def flatten(val, nested = nil)
    case val
    when Array
      return val.map{ |i| flatten(i,1) }.join(" ")
    when Hash
      return val.keys.map{ |i| nested || 
	  i =~ /^-/ ? [i, flatten(val[i],1)] : 
                      [flatten(val[i],1)] }.join(" ")
    else
      return val
    end
  end

  # Read the next line from stdin
  def _get_nextline
    $stdin.readline
  end

  # For each file provided and found, read it in
  def _load_sources( _get_nextline, files )
    text  = ''
    found = []
    
    for i in files
      begin
	f = File.open(i,"r")
      rescue
	next
      end

      if f.tty?
	found.push( '<STDIN>' )
	_get_nextline = method(:_get_nextline)
      else
	found.push( i );
	t = f.readlines.join(' ')
	t.tr!('\t\n',' ')
	text += t
      end
    end

    return nil unless found.size > 0
    text = $stdin.readline if text.empty?
    return [text, found.join(' or ')]
  end


  # Check parameter description for special options
  def _infer(desc, arg, mutex)
    while desc.sub!(/\[\s*mutex:\s*(.*?)\]/i,"")
      _mutex(mutex, "#$1".split(' '))
    end

    if desc =~ /\[\s*no\s*case\s*\]/i
      if arg
	arg.nocase = true
      else 
	nocase = true
      end
    end

    if !arg.nil?
      if desc =~ /.*\[\s*excludes:\s*(.*?)\]/i
	_exclude(mutex, arg.name, ("#$1".split(' ')))
      end

      if desc =~ /.*\[\s*requires:\s*(.*?)\s*\]/i
	arg.requires = "#$1"
      end

      arg.required   = ( desc =~ /\[\s*required\s*\]/i )

      arg.repeatable = ( desc =~ /\[\s*repeatable\s*\]/i )
    end

    _typedef(desc) while desc.sub!(/.*?\[\s*pvtype:\s*/,"")

  end



  # Extract a new type from the description and add it to the list
  # of standard types
  def _typedef(desc)
    se  = DelimScanner::new( desc )
    tmp = se.scanQuotelike

    name = nil
    name, desc = tmp[:delimText], tmp[:suffix]  if tmp

    unless name
      desc.sub!(/\A\s*([^\] \t\n]+)/,"") and name = "#$1"
    end

    raise "Error: bad type directive (missing type name): [pvtype: " +
      desc[0,desc.index(']')||20] + "....\n" unless name

    se  = DelimScanner::new( desc )
    tmp = se.scanQuotelike('\s*:?\s*')

    # @TODO  What is element 2 of extract_quotelike?  :trail is a fake here
    # pat,desc,ind = (extract_quotelike(desc,'\s*:?\s*'))[5,1,2]
    pat = ind = nil
    pat, desc, ind = tmp[:match], tmp[:suffix], tmp[:prefix] if tmp
    pat = pat[1..-2] if pat

    unless pat
      desc.sub!(/\A\s*(:?)\s*([^\] \t\n]+)/,"") and pat = "#$2" and ind = "#$1"
    end

    pat = '' unless pat

    
    se  = DelimScanner::new( desc )
    action = se.extractCodeblock || ''

    desc.sub!( Regexp::quote(action).to_re, '' )
    action = action[1..-2]

    raise "Error: bad type directive (expected closing ']' but found " +
      "'#$1' instead): [pvtype: #{name} " + (pat ? "/#{pat}/" : '') +
      " action:#{action} #$1#$2....\n" if desc =~ /\A\s*([^\] \t\n])(\S*)/
    
    
    Getopt::Declare::ScalarArg::addtype(name,pat,action,ind=~/:/)
  end

  # Handle quote replacements for [ditto] flag
  def _ditto(originalflag, originaldesc, extra)
    if originaldesc =~ /\n.*\n/
      originaldesc = "Same as #{originalflag} "
    else
      originaldesc.chomp
      originaldesc.gsub!(/\S/,'"')
      while originaldesc.gsub!(/"("+)"/,' \1 ')
      end
      originaldesc.gsub!(/""/,'" ')
    end

    "#{originaldesc}#{extra}\n"
  end

  # Check mutex conditions
  def _mutex(mref, mutexlist)
    for flag in mutexlist
      mref[flag] = [] unless mref[flag]
      for otherflag in mutexlist
	next if flag == otherflag
	mref[flag].push( otherflag )
      end
    end
  end

  # Check exclude conditions
  def _exclude(mref, excluded, mutexlist)
    for flag in mutexlist
      unless flag == excluded
	mref[flag]     = [] unless mref[flag]
	mref[excluded] = [] unless mref[excluded]
	mref[excluded].push( flag )
	mref[flag].push( excluded )
      end
    end
  end

  # Returns a regex to match a single argument line
  def re_argument
    /\A(.*?\S.*?#{@@separator})(.*?\n)/
  end

  # Returns a regex to keep matching a multi-line description
  # for an argument.
  def re_more_desc
    /\A((?![ \t]*(\{|\n)|.*?\S.*?#{@@separator}.*?\S).*?\S.*\n)/
  end

  public

  # Constructor
  def initialize(*opts)
    @cache = nil

    Getopt::Declare::Arg::clear

    # HANDLE SHORT-CIRCUITS
    return if opts.size==2 && (!opts[1] || opts[1] == '-SKIP') 

    grammar, source = opts

    if grammar.nil?
      raise "Error: No grammar description provided."
    end

    ### REMOVED PREDEF GRAMMAR AS IT WAS NOT DOCUMENTED NOR 
    ### WORKING IN PERL'S Declare.pm VERSION.

    # PRESERVE ESCAPED '['s
    grammar.gsub!(/\\\[/,"\29")

    # MAKE SURE GRAMMAR ENDS WITH A NEWLINE.
    grammar.sub!(/([^\n])\Z/,'\1'+"\n")

    @usage   = grammar.dup

    # SET-UP
    i = grammar
    _args = []
    _mutex = {}
    _strict = false
    _all_repeatable = false
    _lastdesc = nil
    arg = nil
    Getopt::Declare::nocase = false
    Getopt::Declare::ScalarArg::_reset_stdtype


    # CONSTRUCT GRAMMAR
    while i.length > 0

      # COMMENT:
      i.sub!(/\A[ \t]*#.*\n/,"") and next


      # TYPE DIRECTIVE:
      se  = DelimScanner::new( i )

      if i =~ /\A\s*\[\s*pvtype:/ 
	_action = se.extractBracketed("[")
	if _action
	  i.sub!( Regexp::quote( _action ).to_re, "" )   ### @GGA: added
	  i.sub!(/\A[ \t]*\n/,"")                        ### @GGA: added
	  _action.sub!(/.*?\[\s*pvtype:\s*/,"")
	  _typedef(_action)
	  next
	end # if
      end

      # ACTION  
      codeblockDelimiters = {
	'{'     => '}',
      }

      _action = se.extractCodeblock(codeblockDelimiters)
      if _action
	i.sub!( Regexp::quote(_action ).to_re, "" )
	i.sub!(/\A[ \t]*\n/,"")
	_action = _action[1..-2]

	if !valid_syntax?( _action )
          raise "Error: bad action in Getopt::Declare specification:" +
	    "\n\n#{_action}\n\n\n"
	end

	if _args.length == 0
	  raise "Error: unattached action in Getopt::Declare specification:\n#{_action}\n" +
	        "\t(did you forget the tab after the preceding parameter specification?)\n"
	end

	_args.last.actions.push( _action )
	next
      elsif i =~ /\A(\s*[{].*)/
	raise "Error: incomplete action in Getopt::Declare specification:\n$1.....\n" +
	      "\t(did you forget a closing '}'?)\n"
      end


      # ARG + DESC:
      if i.sub!(re_argument,"")
	spec = "#$1".strip
	desc = "#$2"
	_strict ||= desc =~ /\[\s*strict\s*\]/

        while i.sub!(re_more_desc,"")
          desc += "#$1"
        end
	
	ditto = nil
        if _lastdesc and desc.sub!(/\A\s*\[\s*ditto\s*\]/,_lastdesc)
          ditto = arg
        else
          _lastdesc = desc
        end

        # Check for GNU spec line like:  -d, --debug
        arg = nil
        if spec =~ /(-[\w_\d]+),\s+(--?[\w_\d]+)(\s+.*)?/
          specs = ["#$1#$3", "#$2#$3"]
          specs.each { |spec|
            arg = Arg.new(spec,desc,ditto)
            _args.push( arg )
            _infer(desc, arg, _mutex)
            ditto = arg
          }
        else
          arg = Arg.new(spec,desc,ditto)
          _args.push( arg )
          _infer(desc, arg, _mutex)
        end


	next
      end

      # OTHERWISE: DECORATION
      i.sub!(/((?:(?!\[\s*pvtype:).)*)(\n|(?=\[\s*pvtype:))/,"")
      decorator = "#$1"
      _strict ||= decorator =~ /\[\s*strict\s*\]/
      _infer(decorator, nil, _mutex)

      _all_repeatable = true if decorator =~ /\[\s*repeatable\s*\]/
      @@debug = true if decorator =~ /\[\s*debug\s*\]/

    end # while i.length



    _lastactions = nil
    for i in _args
      if _lastactions && i.ditto && i.actions.size == 0
	i.actions = _lastactions
      else
	_lastactions = i.actions
      end

      if _all_repeatable
	i.repeatable = 1
      end
    end

    # Sort flags based on criteria described in docs
    # Sadly, this cannot be reduced to sort_by
     _args = _args.sort() { |a,b|
      cond1 = ( b.flag.size <=> a.flag.size )
      cond2 = ( b.flag == a.flag and ( b.args.size <=> a.args.size ) )
      cond3 = ( a.id <=> b.id )
      cond1 = nil if cond1 == 0
      cond2 = nil if cond2 == 0
      cond1 or cond2 or cond3
    }

    # Handle clump
    clump = (@usage =~ /\[\s*cluster:\s*none\s*\]/i)     ? 0 :
      (@usage =~ /\[\s*cluster:\s*singles?\s*\]/i) ? 1 :
      (@usage =~ /\[\s*cluster:\s*flags?\s*\]/i)   ? 2 :
      (@usage =~ /\[\s*cluster:\s*any\s*\]/i)      ? 3 :
      (@usage =~ /\[\s*cluster:(.*)\s*\]/i)  	 ? "r" : 3
    raise "Error: unknown clustering mode: [cluster:#$1]\n" if clump == "r"

    # CONSTRUCT OBJECT ITSELF
    @args    = _args
    @mutex   = _mutex
    @helppat = Arg::helppat()
    @verspat = Arg::versionpat()

    @strict  = _strict
    @clump   = clump
    @source  = ''
    @tight   = @usage =~ /\[\s*tight\s*\]/i
    @caller  = caller()

    # VESTIGAL DEBUGGING CODE
    if @@debug
      f = File.new(".CODE.rb","w") and
	f.puts( code() ) and
	f.close() 
    end

    # DO THE PARSE (IF APPROPRIATE)
    if opts.size == 2
      return nil unless parse(source)
    else
      return nil unless parse()
    end

  end # initialize


  # Parse the parameter description and in some cases,
  # optionally eval it, too.
  def parse(*opts)
    source = opts[0]
    _args = nil
    _get_nextline = proc { nil }

    if source
      case source
      when Method
	_get_nextline = source
	_args = _get_nextline.call(self)
	source = '[METHOD]'
      when Proc
	_get_nextline = source
	_args = _get_nextline.call(self)
	source = '[PROC]'
      when IO
	if source.fileno > 0 && source.tty?
	  _get_nextline = method(:_get_nextline)
	  _args = $stdin.readline
	  source = '<STDIN>'
	else
	  _args = source.readlines.join(' ')
	  _args.tr!('\t\n',' ')
	end
      when :build, :skip
        return 0
      when Array
	if source.length() == 1 && !source[0] ||
	    source[0] == "-BUILD" ||
	    source[0] == "-SKIP"
	  return 0
	elsif source.length() == 2 && source[0] == "-ARGV"
	  if !source[1] or !source[1] === Array
	    raise 'Error: parse(["-ARGV"]) not passed an array as second parameter.'
	  end
	  _args  = source[1].map { |i| i.tr( " \t\n", "\0\0\0" ) }.join(' ')
	  source = '<ARRAY>'
	elsif source.length() == 1 && source[0] == "-STDIN"
	  _get_nextline = method(:_get_nextline)
	  _args = $stdin.readline
	  source = '<STDIN>'
	elsif source.length() == 1 && source[0] == '-CONFIG'
	  progname = "#{$0}rc"
	  progname.sub!(%r#.*/#,'')
	  home = ENV['HOME'] || ''
	  _args, source = _load_sources( _get_nextline,
					[ home+"/.#{progname}",
					  ".#{progname}" ] )
	else
	  # Bunch of files to load passed to parse()
	  _args, source = _load_sources( _get_nextline, source )
	end
      when String  # else/case LITERAL STRING TO PARSE
	_args = source.dup
	source = source[0,7] + '...' if source && source.length() > 7
	source = "\"#{source[0..9]}\""
      else
        raise "Unknown source type for Getopt::Declare::parse"
      end  # case
      return 0 unless _args
      source = " (in #{source})"
    else
      _args  = ARGV.map { |i| i.tr( " \t\n", "\0\0\0" ) }.join(' ')
      source = ''
    end

    @source = source
    begin
      err = eval( code(@caller) )
      if $@
	# oops, something wrong... exit
	puts "#{$!}: #{$@.inspect}"
	exit(1)
      end
      if !err
	exit(1)
      end
    rescue
      raise
    end


    true
  end

  def type(*t)
    Getopt::Declare::ScalarArg::addtype(t)
  end

  # Print out version information and maybe exit
  def version(*t)
    prog = "#{$0}"
    begin
      filedate = File.stat( prog ).mtime.localtime()
    rescue
      filedate = 'Unknown date'
    end
    prog.sub!(%r#.*/#,'')
    r = ''
    if defined?(::Timetrap::VERSION)
      r << "\n#{prog}: version #{::Timetrap::VERSION}  (#{filedate})\n\n"
    else
      r << "\n#{prog}: version dated #{filedate}\n\n"
    end

    if t.empty?
      return r
    else
      puts r
      exit t[0]
    end 
  end

  # Print out usage information
  def usage(*opt)

    t = @usage

    lastflag = nil
    lastdesc = nil
    usage = ''

    while !t.empty?

      # COMMENT:
      t.sub!(/\A[ \t]*#.*\n/,".") and next

      # TYPE DIRECTIVE:
      se  = DelimScanner::new( t )

      if t =~ /\A\s*\[\s*pvtype:/
	if action = se.extractBracketed("[")
	  t.sub!(Regexp::quote( action ).to_re,'')
	  t.sub!(/\A[ \t]*\n/,"")  
	  next
	end
      end

      # ACTION
      codeblockDelimiters = {
	'{'     => '}'
      }
      se  = DelimScanner::new( t )
      if action = se.extractCodeblock(codeblockDelimiters)
	t.sub!(Regexp::quote( action ).to_re,'')
	t.sub!(/\A[ \t]*\n/,"")
	decfirst = 0 unless !decfirst.nil?
	next
      end


      # ARG + DESC:
      if t.sub!(re_argument,"")
	decfirst = 0 unless !decfirst.nil?
	spec = "#$1".expand_tabs!()
	desc = "#$2".expand_tabs!()

	while t.gsub!(re_more_desc, '')
	  desc += "#$1".expand_tabs!
	end

	next if desc =~ /\[\s*undocumented\s*\]/i

	uoff = 0
	spec.gsub!(/(<[a-zA-Z]\w*):([^>]+)>/e) { |i|
	  uoff += 1 + "#$2".length() and "#$1>"
        }
	spec.gsub!(/\t/,"=")

	ditto = desc =~ /\A\s*\[ditto\]/
	desc.gsub!(/^\s*\[.*?\]\s*\n/m,"")
	desc.gsub!(BracketDirectives,'')
	#desc.gsub!(/\[.*?\]/,"")

	
	if ditto
	  desc = (lastdesc ? _ditto(lastflag,lastdesc,desc) : "" )
	elsif desc =~ /\A\s*\Z/
	  next
	else
	  lastdesc = desc
	end

	spec =~ /\A\s*(\S+)/ and lastflag = "#$1"
        
        desc.sub!(/\s+\Z/, "\n")
	usage += spec + ' ' * uoff + desc
	next
      end

      

      # OTHERWISE, DECORATION
      if t.sub!(/((?:(?!\[\s*pvtype:).)*)(\n|(?=\[\s*pvtype:))/,"")
	desc = "#$1"+("#$2"||'')
	#desc.gsub!(/^(\s*\[.*?\])+\s*\n/m,'')
	#desc.gsub!(/\[.*?\]/,'')  # eliminates anything in brackets
	if @tight || desc !~ /\A\s*\Z/
	  desc.gsub!(BracketDirectives,'')
	  next if desc =~ /\A\s*\Z/
	end
	decfirst = 1 unless !decfirst.nil? or desc =~ /\A\s*\Z/
	usage += desc
      end

    end  #while

    required = ''
    
    for arg in @args
      required += ' ' + arg.desc + ' '  if arg.required
    end
      
    usage.gsub!(Regexp.new("\29"),"[/") # REINSTATE ESCAPED '['s
      
    required.gsub!(/<([a-zA-Z]\w*):[^>]+>/,'<\1>')
    required.rstrip!
    
    helpcmd = Getopt::Declare::Arg::besthelp
    versioncmd = Getopt::Declare::Arg::bestversion
    
      
    header = ''
    unless @source.nil?
      header << version()
      prog = "#{$0}"
      prog.sub!(%r#.*/#,'')
      header <<  "Usage: #{prog} [options]#{required}\n"
      header <<  "       #{prog} #{helpcmd}\n" if helpcmd
      header <<  "       #{prog} #{versioncmd}\n" if versioncmd
      header <<  "\n" unless decfirst && decfirst == 1 && usage =~ /\A[ \t]*\n/
    end
    
    header << "Options:\n" unless decfirst && decfirst == 1
    
    usage.sub!(/[\s\n]+\Z/m, '')

    pager = $stdout

    #begin
    #  eval('require "IO/Pager";')
    #  pager = IO::Pager.new()
    #rescue
    #end

    if opt.empty?
      pager.puts "#{header}#{usage}"
      return 0
      ### usage
    end

    #usage.sub!(/\A[\s\n]+/m, '')
    pager.puts "#{header}#{usage}"
    exit(opt[0]) if opt[0]
  end

  attr_accessor :unused
  

  # Return list of used parameters (after parsing)
  def used
    used = @cache.keys
    return used.join(' ')
  end

  @@m = []

  # Main method to generate code to be evaluated for parsing.
  def code(*t)
    package = t[0] || ''
    code = %q%


@_deferred = []
@_errormsg = nil
@_finished = nil

begin

  begin
    undef :defer
    undef :reject
    undef :finish
  rescue
  end

  def defer(&i)
    @_deferred.push( i )
  end

  def reject(*i)
    if !i || i[0]
      @_errormsg = i[1] if i[1]
      throw :paramout
    end
  end

  def finish(*i)
    if i.size
      @_finished = i
    else
      @_finished = true
    end
  end

  @unused = []
  @cache  = {}
  _FOUND_ = {}
  _errors = 0
  _invalid = {}
  _lastprefix = nil

  _pos     = 0   # current position to match from
  _nextpos = 0   # next position to match from

  catch(:alldone) do 
    while !@_finished
      begin
	catch(:arg) do
	  @_errormsg = nil

	  # This is used for clustering of flags
	  while _lastprefix
	    substr = _args[_nextpos..-1]
	    substr =~ /^(?!\s|\0|\Z)% +
		Getopt::Declare::Arg::negflagpat() + %q%/ or
	      begin 
		_lastprefix=nil
		break
	      end
	    "#{_lastprefix}#{substr}" =~ /^(% +
		Getopt::Declare::Arg::posflagpat() + %q%)/ or
	      begin 
		_lastprefix=nil
		break
	      end
	    _args = _args[0.._nextpos-1] + _lastprefix + _args[_nextpos..-1]
	    break
	  end #  while _lastprefix

	  % + '' + %q%
	  _pos = _nextpos if _args

	  usage(0) if _args && gindex(_args,/\G(% + @helppat + %q%)(\s|\0|\Z)/,_pos)
          version(0) if _args && _args =~ /\G(% + @verspat + %q%)(\s|\0|\Z)/
      %

	  for arg in @args
	    code << arg.code(self,package)
	  end

	  code << %q%

	if _lastprefix
           _pos = _nextpos + _lastprefix.length()
	   _lastprefix = nil
	   next
        end

	  _pos = _nextpos

	  _args && _pos = gindex( _args, /\G[\s|\0]*(\S+)/, _pos ) or throw(:alldone)

	  if @_errormsg
             $stderr.puts( "Error#{source}: #{@_errormsg}\n" )
          else
             @unused.push( @@m[0] )
          end

	  _errors += 1 if @_errormsg

        end  # catch(:arg)

      ensure  # begin
        _pos = 0 if _pos.nil?
	_nextpos = _pos if _args
	if _args and _args.index( /\G(\s|\0)*\Z/, _pos )
	  _args = _get_nextline.call(self) if !@_finished
          throw(:alldone) unless _args
          _pos = _nextpos = 0
          _lastprefix = ''
	end   # if
      end   # begin/ensure
    end   # while @_finished
  end   # catch(:alldone)
end  # begin

%


	    ################################
	    # Check for required arguments #
	    ################################
	  for arg in @args
	    next unless arg.required

	    code << %q%unless _FOUND_['% + arg.name + %q%'] %

              if @mutex[arg.name]
                for m in @mutex[arg.name]
                  code << %q# or _FOUND_['# + m + %q#']#
                end
              end

	    code << %q%
   $stderr.puts "Error#{@source}: required parameter '% + arg.name + %q%' not found."
   _errors += 1
end
%

	  end

	    ########################################
	    # Check for arguments requiring others #
	    ########################################

	  for arg in @args
	    next unless arg.requires

	    code << %q%
if _FOUND_['% + arg.name + %q%'] && !(% + arg.found_requires +
	      %q%)
   $stderr.puts "Error#{@source}: parameter '% + arg.name + %q%' can only be specified with '% + arg.requires + %q%'"
   _errors += 1
end
            %
	  end

	  code << %q%
#################### Add unused arguments
if _args && _nextpos > 0 && _args.length() > 0
    @unused.replace( @unused + _args[_nextpos..-1].split(' ') )
end

for i in @unused
    i.tr!( "\0", " " )
end

%

          if @strict
	    code << %q%
#################### Handle strict flag
unless _nextpos < ( _args ? _args.length : 0 )
  for i in @unused
    $stderr.puts "Error#{@source}: unrecognizable argument ('#{i}')"
    _errors += 1
  end
end
%
	  end

          code << %q%
#################### Print help hint
if _errors > 0 && !@source.nil?
  $stderr.puts "\n(try '#$0 % + Getopt::Declare::Arg::besthelp + %q%' for more information)"
end

## cannot just assign unused to ARGV in ruby
unless @source != ''
  ARGV.clear
  @unused.map { |i| ARGV.push(i) }
end

unless _errors > 0
  for i in @_deferred
    begin
      i.call
    rescue => e
      STDERR.puts "Action in Getopt::Declare specification produced:\n#{e}"
      _errors += 1
    end
  end
end

!(_errors>0)  # return true or false (false for errors)

%
	return code
  end


  # Inspect cache (not the declare object)
  def inspect
    return nil if !@cache 
    t = ''

    @cache.each { |a,b|
      t << a + " => "
      case b
      when Hash
	t << "{"
	i = []
	b.each { |c,d|
	  i.push( " '#{c}' => " + d.inspect )
	}
	t << i.join(',')
	t << " }"
      else
	t << b.inspect
      end
      t << "\n"
    }
    t << "Unused: " + unused.join(', ')
  end

  # Iterator for Getopt::Declare (travels thru all cache keys)
  def each(&t)
    @cache.each(&t)
  end

  # Operator to easily create new value in of Getopt::Declare
  def []=(name,val)
    @cache = {} unless @cache
    @cache[name] = val
  end

  # Operator to easily return cache of Getopt::Declare
  def [](name)
    if @cache
      return @cache[name]
    else
      return nil
    end
  end

  # Operator to return number of flags set
  def size
    return 0 unless @cache
    return @cache.keys.size
  end

  attr :mutex
  attr :helppat
  attr :verspat
  attr :strict
  attr :clump
  attr :source

 end # class Declare

end # module Getopt
