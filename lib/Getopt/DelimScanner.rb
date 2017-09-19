#!/usr/bin/ruby
# 
# A derivative of StringScanner that can scan for delimited constructs in
# addition to regular expressions. It is a loose port of the Text::Balanced
# module for Perl by Damian Conway <damian@cs.monash.edu.au>.
# 
# == Synopsis
# 
#   se = DelimScanner::new( myString )
# 
# == Authors
# 
# * Michael Granger <ged@FaerieMUD.org>
# * Gonzalo Garramuno <GGarramuno@aol.com>
# 
# Copyright (c) 2002, 2003 The FaerieMUD Consortium. Most rights reserved.
# 
# This work is licensed under the Creative Commons Attribution License. To view
# a copy of this license, visit http://creativecommons.org/licenses/by/1.0 or
# send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California
# 94305, USA.
# 
# == Version
#
#  $Id: DelimScanner.rb,v 1.2 2003/01/12 20:56:51 deveiant Exp $
# 
# == History
#
# - Added :suffix hash key for returning rest (right) of matches, like Perl's
#   Text::Balanced, on several methods.
# - Added one or two \ for backquoting brackets, as new ruby1.8 complains
#

require 'strscan'
require 'forwardable'

### Add some stuff to the String class to allow easy transformation to Regexp
### and in-place interpolation.
class String
    def to_re( casefold=false, extended=false )
        return Regexp::new( self.dup )
    end

    ### Ideas for String-interpolation stuff courtesy of Hal E. Fulton
    ### <hal9000@hypermetrics.com> via ruby-talk

    def interpolate( scope )
        unless scope.is_a?( Binding )
            raise TypeError, "Argument to interpolate must be a Binding, not "\
                "a #{scope.class.name}"
        end

        # $stderr.puts ">>> Interpolating '#{self}'..."

        copy = self.gsub( /"/, %q:\": )
        eval( '"' + copy + '"', scope )
    end

end


### A derivative of StringScanner that can scan for delimited constructs in
### addition to regular expressions.
class DelimScanner

    ### Scanner exception classes
    class MatchFailure < RuntimeError ; end
    class DelimiterError < RuntimeError ; end
    

    extend Forwardable
    StringScanner.must_C_version


    ### Class constants
    Version = /([\d\.]+)/.match( %q{$Revision: 1.2 $} )[1]
    Rcsid = %q$Id: DelimScanner.rb,v 1.2 2003/01/12 20:56:51 deveiant Exp $

    # Pattern to match a valid XML name
    XmlName = '[a-zA-Z_:][a-zA-Z0-9:.-]*'


    ### Namespace module for DelimString constants
    module Default

        # The list of default opening => closing codeblock delimiters to use for
        # scanCodeblock.
        CodeblockDelimiters = {
            '{'     => '}',
            'begin' => 'end',
            'do'    => 'end',
        }

        # Default scanMultiple operations and their arguments
        MultipleFunctions = [
            :scanVariable   => [],
            :scanQuotelike  => [],
            :scanCodeblock  => [],
        ]

    end
    include Default


    ### Define delegating methods that cast their argument to a Regexp from a
    ### String. This allows the scanner's scanning methods to be called with
    ### Strings in addition to Regexps. This was mostly stolen from
    ### forwardable.rb.
    def self.def_casting_delegators( *methods )
        methods.each {|methodName|
            class_eval( <<-EOF, "(--def_casting_delegators--)", 1 )
                def #{methodName}( pattern )
                    pattern = pattern.to_s.to_re unless pattern.is_a?( Regexp )
                    @scanner.#{methodName}( pattern )
                end
            EOF
        }
    end

    
    ### Create a new DelimScanner object for the specified <tt>string</tt>. If
    ### <tt>dup</tt> is <tt>true</tt>, a duplicate of the target string will be
    ### used instead of the one given. The target string will be frozen after
    ### the scanner is created.
    def initialize( string, dup=true )
        @scanner    = StringScanner::new( string, dup )
        @matchError = nil
        @debugLevel = 0
    end


    
    ######
    public
    ######

    # Here, some delegation trickery is done to make a DelimScanner behave like
    # a StringScanner. Some methods are directly delegated, while some are
    # delegated via a method which casts its argument to a Regexp first so some
    # scanner methods can be called with Strings as well as Regexps.

    # A list of delegated methods that need casting.
    NeedCastingDelegators = :scan, :skip, :match?, :check,
        :scan_until, :skip_until, :exist?, :check_until

    # Delegate all StringScanner instance methods to the associated scanner
    # object, except those that need a casting delegator, which uses an indirect
    # delegation method.
    def_delegators :@scanner,
        *( StringScanner.instance_methods(false) - 
	   NeedCastingDelegators.collect {|sym| sym.id2name} )

    def_casting_delegators( *NeedCastingDelegators )


    
    # The last match error encountered by the scanner
    attr_accessor :matchError
    protected :matchError=  ;   # ; is to work around a ruby-mode indent bug
    
    # Debugging level
    attr_accessor :debugLevel


    
    ### Returns <tt>true</tt> if the scanner has encountered a match error.
    def matchError?
        return ! @matchError.nil?
    end


    ### Starting at the scan pointer, try to match a substring delimited by the
    ### specified <tt>delimiters</tt>, skipping the specified <tt>prefix</tt>
    ### and any character escaped by the specified <tt>escape</tt>
    ### character/s. If matched, advances the scan pointer and returns a Hash
    ### with the following key/value pairs on success:
    ### 
    ### [<tt>:match</tt>]
    ###   The text of the match, including delimiters.
    ### [<tt>:prefix</tt>]
    ###   The matched prefix, if any.
    ###
    ### If the match fails, returns nil.
    def scanDelimited( delimiters="'\"`", prefix='\\s*', escape='\\' )
        delimiters  ||= "'\"`"
        prefix      ||= '\\s*'
        escape      ||= '\\'

        debugMsg( 1, "Scanning for delimited text: delim = (%s), prefix=(%s), escape=(%s)",
                  delimiters, prefix, escape )
        self.matchError = nil

        # Try to match the prefix first to get the length
        unless (( prefixLength = self.match?(prefix.to_re) ))
            self.matchError = "Failed to match prefix '%s' at offset %d" %
                [ prefix, self.pointer ]
            return nil
        end
            
        # Now build a delimited pattern with the specified parameters.
        delimPattern = makeDelimPattern( delimiters, escape, prefix )
        debugMsg( 2, "Delimiter pattern is %s" % delimPattern.inspect )

        # Fail if no match
        unless (( matchedString = self.scan(delimPattern) ))
            self.matchError = "No delimited string found."
            return nil
        end

        return {
            :match  => matchedString[prefixLength .. -1],
            :prefix => matchedString[0..prefixLength-1],
        }
    end


    ### Match using the #scanDelimited method, but only return the match or nil.
    def extractDelimited( *args )
        rval = scanDelimited( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring delimited by the
    ### specified <tt>delimiters</tt>, skipping the specified <tt>prefix</tt>
    ### and any character escaped by the specified <tt>escape</tt>
    ### character/s. If matched, advances the scan pointer and returns the
    ### length of the matched string; if it fails the match, returns nil.
    def skipDelimited( delimiters="'\"`", prefix='\\s*', escape='\\' )
        delimiters  ||= "'\"`"
        prefix      ||= '\\s*'
        escape      ||= '\\'

        self.matchError = nil
        return self.skip( makeDelimPattern(delimiters, escape, prefix) )
    end


    ### Starting at the scan pointer, try to match a substring delimited by
    ### balanced <tt>delimiters</tt> of the type specified, after skipping the
    ### specified <tt>prefix</tt>. On a successful match, this method advances
    ### the scan pointer and returns a Hash with the following key/value pairs:
    ### 
    ### [<tt>:match</tt>]
    ###   The text of the match, including the delimiting brackets.
    ### [<tt>:prefix</tt>]
    ###   The matched prefix, if any.
    ###
    ### On failure, returns nil.
    def scanBracketed( delimiters="{([<", prefix='\s*' )
        delimiters  ||= "{([<"
        prefix      ||= '\s*'

        prefix = prefix.to_re unless prefix.kind_of?( Regexp )

        debugMsg( 1, "Scanning for bracketed text: delimiters = (%s), prefix = (%s)",
                  delimiters, prefix )

        self.matchError = nil

        # Split the left-delimiters (brackets) from the quote delimiters.
        ldel = delimiters.dup
        qdel = ldel.squeeze.split(//).find_all {|char| char =~ /["'`]/ }.join('|')
        qdel = nil if qdel.empty?
        quotelike = true if ldel =~ /q/

        # Change all instances of delimiters to the left-hand versions, and
        # strip away anything but bracketing delimiters
        ldel = ldel.tr( '[](){}<>', '[[(({{<<' ).gsub(/[^#{Regexp.quote('[\\](){}<>')}]+/, '').squeeze

        ### Now build the right-delim equivalent of the left delim string
        rdel = ldel.dup
        unless rdel.tr!( '[({<', '])}>' )
            raise DelimiterError, "Did not find a suitable bracket in delimiter: '#{delimiters}'"
        end

        # Build regexps from both bracketing delimiter strings
        ldel = ldel.split(//).collect {|ch| Regexp.quote(ch)}.join('|')
        rdel = rdel.split(//).collect {|ch| Regexp.quote(ch)}.join('|')

        depth = self.scanDepth
        result = nil
        startPos = self.pointer

        begin
            result = matchBracketed( prefix, ldel, qdel, quotelike, rdel )
        rescue MatchFailure => e
            debugMsg( depth + 1, "Match error: %s" % e.message )
            self.matchError = e.message
            self.pointer = startPos
            result = nil
        rescue => e
            self.pointer = startPos
            Kernel::raise
        end

        return result
    end


    ### Match using the #scanBracketed method, but only return the match or nil.
    def extractBracketed( *args )
        rval = scanBracketed( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring with
    ### #scanBracketed. On a successful match, this method advances the scan
    ### pointer and returns the length of the match, including the delimiters
    ### and any prefix that was skipped. On failure, returns nil.
    def skipBracketed( *args )
        startPos = self.pointer

        match = scanBracketed( *args )

        return nil unless match
        return match.length + prefix.length
    ensure
        debugMsg( 2, "Resetting scan pointer." )
        self.pointer = startPos
    end


    ### Extracts and segments text from the scan pointer forward that occurs
    ### between (balanced) specified tags, after skipping the specified
    ### <tt>prefix</tt>. If the opentag argument is <tt>nil</tt>, a pattern which
    ### will match any standard HTML/XML tag will be used. If the
    ### <tt>closetag</tt> argument is <tt>nil</tt>, a pattern is created which
    ### prepends a <tt>/</tt> character to the matched opening tag, after any
    ### bracketing characters. The <tt>options</tt> argument is a Hash of one or
    ### more options which govern the matching operation. They are described in
    ### more detail in the Description section of 'lib/DelimScanner.rb'. On a
    ### successful match, this method advances the scan pointer and returns an
    ### 
    ### [<tt>:match</tt>]
    ###   The text of the match, including the delimiting tags.
    ### [<tt>:prefix</tt>]
    ###   The matched prefix, if any.
    ###
    ### On failure, returns nil.
    def scanTagged( opentag=nil, closetag=nil, prefix='\s*', options={} )
        prefix ||= '\s*'

        ldel = opentag || %Q,<\\w+(?:#{ makeDelimPattern(%q:'":) }|[^>])*>,
        rdel = closetag
        raise ArgumentError, "Options argument must be a hash" unless options.kind_of?( Hash )

        failmode    = options[:fail]
        bad     = if options[:reject].is_a?( Array ) then
                      options[:reject].join("|")
                  else
                      (options[:reject] || '')
                  end
        ignore  = if options[:ignore].is_a?( Array ) then
                      options[:ignore].join("|")
                  else
                      (options[:ignore] || '')
                  end

        self.matchError = nil
        result          = nil
        startPos        = self.pointer

        depth = self.scanDepth

        begin
            result = matchTagged( prefix, ldel, rdel, failmode, bad, ignore )
        rescue MatchFailure => e
            debugMsg( depth + 1, "Match error: %s" % e.message )
            self.matchError = e.message
            self.pointer = startPos
            result = nil
        rescue => e
            self.pointer = startPos
            Kernel::raise
        end

        return result
    end


    ### Match using the #scanTagged method, but only return the match or nil.
    def extractTagged( *args )
        rval = scanTagged( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring with
    ### #scanTagged. On a successful match, this method advances the scan
    ### pointer and returns the length of the match, including any delimiters
    ### and any prefix that was skipped. On failure, returns nil.
    def skipTagged( *args )
        startPos = self.pointer

        match = scanTagged( *args )

        return nil unless match
        return match.length + prefix.length
    ensure
        debugMsg( 2, "Resetting scan pointer." )
        self.pointer = startPos
    end


    # :NOTE:
    # Since the extract_quotelike function isn't documented at all in
    # Text::Balanced, I'm only guessing this is correct...

    ### Starting from the scan pointer, try to match any one of the various Ruby
    ### quotes and quotelike operators after skipping the specified
    ### <tt>prefix</tt>.  Nested backslashed delimiters, embedded balanced
    ### bracket delimiters (for the quotelike operators), and trailing modifiers
    ### are all caught. If <tt>matchRawRegex</tt> is <tt>true</tt>, inline
    ### regexen (eg., <tt>/pattern/</tt>) are matched as well. Advances the scan
    ### pointer and returns a Hash with the following key/value pairs on
    ### success:
    ### 
    ### [<tt>:match</tt>]
    ###   The entire text of the match.
    ### [<tt>:prefix</tt>]
    ###   The matched prefix, if any.
    ### [<tt>:quoteOp</tt>]
    ###   The name of the quotelike operator (if any) (eg., '%Q', '%r', etc).
    ### [<tt>:leftDelim</tt>]
    ###   The left delimiter of the first block of the operation.
    ### [<tt>:delimText</tt>]
    ###   The text of the first block of the operation.
    ### [<tt>:rightDelim</tt>]
    ###   The right delimiter of the first block of the operation.
    ### [<tt>:modifiers</tt>]
    ###   The trailing modifiers on the operation (if any).
    ### 
    ### On failure, returns nil.
    def scanQuotelike( prefix='\s*', matchRawRegex=true )

        self.matchError = nil
        result          = nil
        startPos        = self.pointer

        depth = self.scanDepth

        begin
            result = matchQuotelike( prefix, matchRawRegex )
        rescue MatchFailure => e
            debugMsg( depth + 1, "Match error: %s" % e.message )
            self.matchError = e.message
            self.pointer = startPos
            result = nil
        rescue => e
            self.pointer = startPos
            Kernel::raise
        end

        return result
    end

    
    ### Match using the #scanQuotelike method, but only return the match or nil.
    def extractQuotelike( *args )
        rval = scanQuotelike( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring with
    ### #scanQuotelike. On a successful match, this method advances the scan
    ### pointer and returns the length of the match, including any delimiters
    ### and any prefix that was skipped. On failure, returns nil.
    def skipQuotelike( *args )
        startPos = self.pointer

        match = scanQuotelike( *args )

        return nil unless match
        return match.length + prefix.length
    ensure
        debugMsg( 2, "Resetting scan pointer." )
        self.pointer = startPos
    end


    ### Starting from the scan pointer, try to match a Ruby variable after
    ### skipping the specified prefix.
    def scanVariable( prefix='\s*' )
        self.matchError = nil
        result          = nil
        startPos        = self.pointer

        depth = self.scanDepth

        begin
            result = matchVariable( prefix )
        rescue MatchFailure => e
            debugMsg( depth + 1, "Match error: %s" % e.message )
            self.matchError = e.message
            self.pointer = startPos
            result = nil
        rescue => e
            self.pointer = startPos
            Kernel::raise
        end

        return result
    end


    ### Match using the #scanVariable method, but only return the match or nil.
    def extractVariable( *args )
        rval = scanVariable( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring with
    ### #scanVariable. On a successful match, this method advances the scan
    ### pointer and returns the length of the match, including any delimiters
    ### and any prefix that was skipped. On failure, returns nil.
    def skipVariable( *args )
        startPos = self.pointer

        match = scanVariable( *args )

        return nil unless match
        return match.length + prefix.length
    ensure
        debugMsg( 2, "Resetting scan pointer." )
        self.pointer = startPos
    end


    ### Starting from the scan pointer, and skipping the specified
    ### <tt>prefix</tt>, try to to recognize and match a balanced bracket-,
    ### do/end-, or begin/end-delimited substring that may contain unbalanced
    ### delimiters inside quotes or quotelike operations.
    def scanCodeblock( innerDelim=CodeblockDelimiters, prefix='\s*', outerDelim=innerDelim )
        self.matchError = nil
        result          = nil
        startPos        = self.pointer

        prefix          ||= '\s*'
        innerDelim      ||= CodeblockDelimiters
        outerDelim      ||= innerDelim

        depth = caller(1).find_all {|frame|
            frame =~ /in `scan(Variable|Tagged|Codeblock|Bracketed|Quotelike)'/
        }.length

        begin
            debugMsg 3, "------------------------------------"
            debugMsg 3, "Calling matchCodeBlock( %s, %s, %s )",
                prefix.inspect, innerDelim.inspect, outerDelim.inspect
            debugMsg 3, "------------------------------------"
            result = matchCodeblock( prefix, innerDelim, outerDelim )
        rescue MatchFailure => e
            debugMsg( depth + 1, "Match error: %s" % e.message )
            self.matchError = e.message
            self.pointer = startPos
            result = nil
        rescue => e
            self.pointer = startPos
            Kernel::raise
        end

        return result
    end


    ### Match using the #scanCodeblock method, but only return the match or nil.
    def extractCodeblock( *args )
        rval = scanCodeblock( *args ) or return nil
        return rval[:match]
    end


    ### Starting at the scan pointer, try to match a substring with
    ### #scanCodeblock. On a successful match, this method advances the scan
    ### pointer and returns the length of the match, including any delimiters
    ### and any prefix that was skipped. On failure, returns nil.
    def skipCodeblock( *args )
        startPos = self.pointer

        match = scanCodeblock( *args )

        return nil unless match
        return match.length + prefix.length
    ensure
        debugMsg( 2, "Resetting scan pointer." )
        self.pointer = startPos
    end




    #########
    protected
    #########

    ### Scan the string from the scan pointer forward, skipping the specified
    ### <tt>prefix</tt> and trying to match a string delimited by bracketing
    ### delimiters <tt>ldel</tt> and <tt>rdel</tt> (Regexp objects), and quoting
    ### delimiters <tt>qdel</tt> (Regexp). If <tt>quotelike</tt> is
    ### <tt>true</tt>, Ruby quotelike constructs will also be honored.
    def matchBracketed( prefix, ldel, qdel, quotelike, rdel )
        startPos = self.pointer
        debugMsg( 2, "matchBracketed starting at pos = %d: prefix = %s, "\
                 "ldel = %s, qdel = %s, quotelike = %s, rdel = %s",
                 startPos, prefix.inspect, ldel.inspect, qdel.inspect, quotelike.inspect,
                 rdel.inspect )

        # Test for the prefix, failing if not found
        raise MatchFailure, "Did not find prefix: #{prefix.inspect}" unless 
            self.skip( prefix )

        # Mark this position as the left-delimiter pointer
        ldelpos = self.pointer
        debugMsg( 3, "Found prefix. Left delim pointer at %d", ldelpos )
        
        # Match opening delimiter or fail
        unless (( delim = self.scan(ldel) ))
            raise MatchFailure, "Did not find opening bracket after prefix: '%s' (%d)" %
                [ self.string[startPos..ldelpos].chomp, ldelpos ]
        end

        # A stack to keep track of nested delimiters
        nesting = [ delim ]
        debugMsg( 3, "Found opening bracket. Nesting = %s", nesting.inspect )
        
        while self.rest?

            debugMsg( 5, "Starting scan loop. Nesting = %s", nesting.inspect )

            # Skip anything that's backslashed
            if self.skip( /\\./ )
                debugMsg( 4, "Skipping backslashed literal at offset %d: '%s'",
                          self.pointer - 2, self.string[ self.pointer - 2, 2 ].chomp )
                next
            end

            # Opening bracket (left delimiter)
            if self.scan(ldel)
                delim = self.matched
                debugMsg( 4, "Found opening delim %s at offset %d",
                          delim.inspect, self.pointer - 1 )
                nesting.push delim

            # Closing bracket (right delimiter)
            elsif self.scan(rdel)
                delim = self.matched

                debugMsg( 4, "Found closing delim %s at offset %d",
                          delim.inspect, self.pointer - 1 )

                # :TODO: When is this code reached?
                if nesting.empty?
                    raise MatchFailure, "Unmatched closing bracket '%s' at offset %d" %
                        [ delim, self.pointer - 1 ]
                end

                # Figure out what the compliment of the bracket next off the
                # stack should be.
                expected = nesting.pop.tr( '({[<', ')}]>' )
                debugMsg( 4, "Got a '%s' bracket off nesting stack", expected )

                # Check for mismatched brackets
                if expected != delim
                    raise MatchFailure, "Mismatched closing bracket at offset %d: "\
                        "Expected '%s', but found '%s' instead." %
                        [ self.pointer - 1, expected, delim ]
                end

                # If we've found the closing delimiter, stop scanning
                if nesting.empty?
                    debugMsg( 4, "Finished with scan: nesting stack empty." )
                    break
                end

            # Quoted chunk (quoted delimiter)
            elsif qdel && self.scan(qdel)
                match = self.matched

                if self. scan( /[^\\#{match}]*(?:\\.[^\\#{match}]*)*(#{Regexp::quote(match)})/ )
                    debugMsg( 4, "Skipping quoted chunk. Scan pointer now at offset %d", self.pointer )
                    next
                end

                raise MatchFailure, "Unmatched embedded quote (%s) at offset %d" %
                    [ match, self.pointer - 1 ]

            # Embedded quotelike
            elsif quotelike && self.scanQuotelike
                debugMsg( 4, "Matched a quotelike. Scan pointer now at offset %d", self.pointer )
                next

            # Skip word characters, or a single non-word character
            else
                self.skip( /(?:[a-zA-Z0-9]+|.)/m )
                debugMsg 5, "Skipping '%s' at offset %d." %
                    [ self.matched, self.pointer ]
            end

        end

        # If there's one or more brackets left on the delimiter stack, we're
        # missing a closing delim.
        unless nesting.empty?
            raise MatchFailure, "Unmatched opening bracket(s): %s.. at offset %d" %
                [ nesting.join('..'), self.pointer ]
        end

        rval = {
            :match  => self.string[ ldelpos .. (self.pointer - 1) ],
            :prefix => self.string[ startPos, (ldelpos-startPos) ],
            :suffix => self.string[ self.pointer..-1 ],
        }
        debugMsg 1, "matchBracketed succeeded: %s" % rval.inspect
        return rval
    end


    ### Starting from the scan pointer, skip the specified <tt>prefix</tt>, and
    ### try to match text bracketed by the given left and right tag-delimiters
    ### (<tt>ldel</tt> and <tt>rdel</tt>). 
    def matchTagged( prefix, ldel, rdel, failmode, bad, ignore )
        failmode = failmode.to_s.intern if failmode
        startPos = self.pointer
        debugMsg 2, "matchTagged starting at pos = %d: prefix = %s, "\
                 "ldel = %s, rdel = %s, failmode = %s, bad = %s, ignore = %s",
                 startPos, prefix.inspect, ldel.inspect, rdel.inspect,
                 failmode.inspect, bad.inspect, ignore.inspect

        rdelspec = ''
        openTagPos, textPos, paraPos, closeTagPos, endPos = ([nil] * 5)
        match = nil

        # Look for the prefix
        raise MatchFailure, "Did not find prefix: /#{prefix.inspect}/" unless
            self.skip( prefix )

        openTagPos = self.pointer
        debugMsg 3, "Found prefix. Pointer now at offset %d" % self.pointer

        # Look for the opening delimiter
        unless (( match = self.scan(ldel) ))
            raise MatchFailure, "Did not find opening tag %s at offset %d" % 
                [ ldel.inspect, self.pointer ]
        end

        textPos = self.pointer
        debugMsg 3, "Found left delimiter '%s': offset now %d" % [ match, textPos ]

        # Make a right delim out of the tag we found if none was specified
        if rdel.nil?
            rdelspec = makeClosingTag( match )
            debugMsg 3, "Generated right-delimiting tag: %s" % rdelspec.inspect
        else
            # Make the regexp-related globals from the match
            rdelspec = rdel.gsub( /(\A|[^\\])\$([1-9])/, '\1self[\2]' ).interpolate( binding )
            debugMsg 3, "Right delimiter (after interpolation) is: %s" % rdelspec.inspect
        end

        # Process until we reach the end of the string or find a closing tag
        while self.rest? && closeTagPos.nil?

            # Skip backslashed characters
            if (( self.skip( /^\\./ ) ))
                debugMsg 4, "Skipping backslashed literal at offset %d" % self.pointer
                next

            # Match paragraphs-break for fail == :para
            elsif (( matchlength = self.skip( /^(\n[ \t]*\n)/ ) ))
                paraPos ||= self.pointer - matchlength
                debugMsg 4, "Found paragraph position at offset %d" % paraPos
                
            # Match closing tag
            elsif (( matchlength = self.skip( rdelspec ) ))
                closeTagPos = self.pointer - matchlength
                debugMsg 3, "Found closing tag at offset %d" % closeTagPos

            # If we're ignoring anything, try to match and move beyond it
            elsif ignore && !ignore.empty? && self.skip(ignore)
                debugMsg 3, "Skipping ignored text '%s' at offset %d" %
                    [ self.matched, self.pointer - self.matched_size ]
                next

            # If there's a "bad" pattern, try to match it, shorting the
            # outer loop if it matches in para or max mode, or failing with
            # a match error if not.
            elsif bad && !bad.empty? && self.match?( bad )
                if failmode == :para || failmode == :max
                    break
                else
                    raise MatchFailure, "Found invalid nested tag '%s' at offset %d" %
                        [ match, self.pointer ]
                end

            # If there's another opening tag, make a recursive call to
            # ourselves to move the cursor beyond it
            elsif (( match = self.scan( ldel ) ))
                tag = match
                self.unscan

                unless self.matchTagged( prefix, ldel, rdel, failmode, bad, ignore )
                    break if failmode == :para || failmode == :max

                    raise MatchFailure, "Found unbalanced nested tag '%s' at offset %d" %
                        [ tag, self.pointer ]
                end

            else 
                self.pointer += 1
                debugMsg 5, "Advanced scan pointer to offset %d" % self.pointer
            end
        end

        # If the closing hasn't been found, then it's a "short" match, which is
        # okay if the failmode indicates we don't care. Otherwise, it's an error.
        unless closeTagPos
            debugMsg 3, "No close tag position found. "
            
            if failmode == :max || failmode == :para
                closeTagPos = self.pointer - 1
                debugMsg 4, "Failmode %s tolerates no closing tag. Close tag position set to %d" %
                    [ failmode.inspect, closeTagPos ]

                # Sync the scan pointer and the paragraph marker if it's set.
                if failmode == :para && paraPos
                    self.pointer = paraPos + 1
                end
            else
                raise MatchFailure, "No closing tag found."
            end
        end

        rval = {
            :match  => self.string[ openTagPos .. (self.pointer - 1) ],
            :prefix => self.string[ startPos, (openTagPos-startPos) ],
            :suffix => self.string[ self.pointer..-1 ],
        }
        debugMsg 1, "matchTagged succeeded: %s" % rval.inspect
        return rval
    end


    ### Starting from the scan pointer, skip the specified <tt>prefix</tt>, and
    ### try to match text inside a Ruby quotelike construct. If
    ### <tt>matchRawRegex</tt> is <tt>true</tt>, the regex construct
    ### <tt>/pattern/</tt> is also matched.
    def matchQuotelike( prefix, matchRawRegex )
        startPos = self.pointer
        debugMsg 2, "matchQuotelike starting at pos = %d: prefix = %s, "\
            "matchRawRegex = %s",
            startPos, prefix.inspect, matchRawRegex.inspect

        # Init position markers
        rval = oppos = preldpos = ldpos = strpos = rdpos = modpos = nil

        # Look for the prefix
        raise MatchFailure, "Did not find prefix: /#{prefix.inspect}/" unless
            self.skip( prefix )
        oppos = self.pointer


        # Peek at the next character
        # If the initial quote is a simple quote, our job is easy
        if self.check(/^["`']/) || ( matchRawRegex && self.check(%r:/:) )

            initial = self.matched

            # Build the pattern for matching the simple string
            pattern = "%s [^\\%s]* (\\.[^\\%s]*)* %s" %
                [ Regexp.quote(initial),
                  initial, initial,
                  Regexp.quote(initial) ]
            debugMsg 2, "Matching simple quote at offset %d with /%s/" % 
                [ self.pointer, pattern ]

            # Search for it, raising an exception if it's not found
            unless self.scan( /#{pattern}/xism )
                raise MatchFailure,
                    "Did not find closing delimiter to match '%s' at '%s...' (offset %d)" %
                    [ initial, self.string[ oppos, 20 ].chomp, self.pointer ]
            end

            modpos = self.pointer
            rdpos = modpos - 1

            # If we're matching a regex, look for any trailing modifiers
            if initial == '/'
                pattern = if RUBY_VERSION >= "1.7.3" then /[imoxs]*/ else /[imox]*/ end
                self.scan( pattern )
            end

            rval = {
                :prefix     => self.string[ startPos, (oppos-startPos) ],
                :match      => self.string[ oppos .. (self.pointer - 1) ],
                :leftDelim  => self.string[ oppos, 1 ],
                :delimText  => self.string[ (oppos+1) .. (rdpos-1) ],
                :rightDelim => self.string[ rdpos, 1 ],
                :modifiers  => self.string[ modpos, (self.pointer-modpos) ],
                :suffix     => self.string[ self.pointer.. -1 ],
            }

        # If it's one of the fancy quotelike operators, our job is somewhat
        # complicated (though nothing like Perl's, thank the Goddess)
        elsif self.scan( %r:%[rwqQx]?(?=\S): )
            op = self.matched
            debugMsg 2, "Matching a real quotelike ('%s') at offset %d" % 
                [ op, self.pointer ]
            modifiers = nil

            ldpos = self.pointer
            strpos = ldpos + 1

            # Peek ahead to see what the delimiter is
            ldel = self.check( /\S/ )
            
            # If it's a bracketing character, just use matchBracketed
            if ldel =~ /[\[(<{]/
                rdel = ldel.tr( '[({<', '])}>' )
                debugMsg 4, "Left delim is a bracket: %s; looking for compliment: %s" %
                    [ ldel, rdel ]
                self.matchBracketed( '', Regexp::quote(ldel), nil, nil, Regexp::quote(rdel) )
            else
                debugMsg 4, "Left delim isn't a bracket: '#{ldel}'; looking for closing instance"
                self.scan( /#{ldel}[^\\#{ldel}]*(\\.[^\\#{ldel}]*)*#{ldel}/ ) or
                    raise MatchFailure,
                    "Can't find a closing delimiter '%s' at '%s...' (offset %d)" %
                    [ ldel, self.rest[0,20].chomp, self.pointer ]
            end
            rdelpos = self.pointer - 1

            # Match modifiers for Regexp quote
            if op == '%r'
                pattern = if RUBY_VERSION >= "1.7.3" then /[imoxs]*/ else /[imox]*/ end
                modifiers = self.scan( pattern ) || ''
            end

            rval = {
                :prefix     => self.string[ startPos, (oppos-startPos) ],
                :match      => self.string[ oppos .. (self.pointer - 1) ],
                :quoteOp    => op,
                :leftDelim  => self.string[ ldpos, 1 ],
                :delimText  => self.string[ strpos, (rdelpos-strpos) ],
                :rightDelim => self.string[ rdelpos, 1 ],
                :modifiers  => modifiers,
                :suffix     => self.string[ self.pointer.. -1 ],
            }

        # If it's a here-doc, things get even hairier.
        elsif self.scan( %r:<<(-)?: )
            debugMsg 2, "Matching a here-document at offset %d" % self.pointer
            op = self.matched

            # If there was a dash, start with optional whitespace
            indent = self[1] ? '\s*' : ''
            ldpos = self.pointer
            label = ''

            # Plain identifier
            if self.scan( /[A-Za-z_]\w*/ )
                label = self.matched
                debugMsg 3, "Setting heredoc terminator to bare identifier '%s'" % label

            # Quoted string
            elsif self.scan( / ' ([^'\\]* (?:\\.[^'\\]*)*) ' /sx ) ||
                  self.scan( / " ([^"\\]* (?:\\.[^"\\]*)*) " /sx ) ||
                  self.scan( / ` ([^`\\]* (?:\\.[^`\\]*)*) ` /sx )
                label = self[1]
                debugMsg 3, "Setting heredoc terminator to quoted identifier '%s'" % label

            # Ruby, unlike Perl, requires a terminal, even if it's only an empty
            # string
            else
                raise MatchFailure,
                    "Missing heredoc terminator before end of line at "\
                    "'%s...' (offset %d)" %
                    [ self.rest[0,20].chomp, self.pointer ]
            end
            extrapos = self.pointer

            # Advance to the beginning of the string
            self.skip( /.*\n/ )
            strpos = self.pointer
            debugMsg 3, "Scanning until /\\n#{indent}#{label}\\n/m"

            # Match to the label
            unless self.scan_until( /\n#{indent}#{label}\n/m )
                raise MatchFailure,
                    "Couldn't find heredoc terminator '%s' after '%s...' (offset %d)" %
                    [ label, self.rest[0,20].chomp, self.pointer ]
            end

            rdpos = self.pointer - self.matched_size

            rval = {
                :prefix     => self.string[ startPos, (oppos-startPos) ],
                :match      => self.string[ oppos .. (self.pointer - 1) ],
                :quoteOp    => op,
                :leftDelim  => self.string[ ldpos, (extrapos-ldpos) ],
                :delimText  => self.string[ strpos, (rdpos-strpos) ],
                :rightDelim => self.string[ rdpos, (self.pointer-rdpos) ],
                :suffix     => self.string[ self.pointer.. -1 ],
            }

        else
            raise MatchFailure,
                "No quotelike operator found after prefix at '%s...'" %
                    self.rest[0,20].chomp
        end

        
        debugMsg 1, "matchQuotelike succeeded: %s" % rval.inspect
        return rval
    end


    ### Starting from the scan pointer, skip the specified <tt>prefix</tt>, and
    ### try to match text that is a valid Ruby variable or identifier, ...?
    def matchVariable( prefix )
        startPos = self.pointer
        debugMsg 2, "matchVariable starting at pos = %d: prefix = %s",
                 startPos, prefix.inspect

        # Look for the prefix
        raise MatchFailure, "Did not find prefix: /#{prefix.inspect}/" unless
            self.skip( prefix )

        varPos = self.pointer

        # If the variable matched is a predefined global, no need to look for an
        # identifier
        unless self.scan( %r~\$(?:[!@/\\,;.<>$?:_\~&`'+]|-\w|\d+)~ )

            debugMsg 2, "Not a predefined global at '%s...' (offset %d)" %
                [ self.rest[0,20].chomp, self.pointer ]
            
            # Look for a valid identifier
            unless self.scan( /\*?(?:[$@]|::)?(?:[a-z_]\w*(?:::\s*))*[_a-z]\w*/is )
                raise MatchFailure, "No variable found: Bad identifier (offset %d)" % self.pointer
            end
        end

        debugMsg 2, "Matched '%s' at offset %d" % [ self.matched, self.pointer ]

        # Match methodchain with trailing codeblock
        while self.rest?
            # Match a regular chained method
            next if scanCodeblock( {"("=>")", "do"=>"end", "begin"=>"end", "{"=>"}"},
                                   /\s*(?:\.|::)\s*[a-zA-Z_]\w+\s*/ )

            # Match a trailing block or an element ref
            next if scanCodeblock( nil, /\s*/, {'{' => '}', '[' => ']'} )

            # This matched a dereferencer in Perl, which doesn't have any
            # equivalent in Ruby.
            #next if scanVariable( '\s*(\.|::)\s*' )

            # Match a method call without parens (?)
            next if self.scan( '\s*(\.|::)\s*\w+(?![{(\[])' )

            break
        end

        rval = {
            :match  => self.string[ varPos .. (self.pointer - 1) ],
            :prefix => self.string[ startPos, (varPos-startPos) ],
            :suffix => self.string[ self.pointer..-1 ],
        }
        debugMsg 1, "matchVariable succeeded: %s" % rval.inspect
        return rval
    end


    ### Starting from the scan pointer, skip the specified <tt>prefix</tt>, and
    ### try to match text inside a Ruby code block construct which must be
    ### delimited by the specified <tt>outerDelimPairs</tt>. It may optionally
    ### contain sub-blocks delimited with the given <tt>innerDelimPairs</tt>.
    def matchCodeblock( prefix, innerDelimPairs, outerDelimPairs )
        startPos = self.pointer
        debugMsg 2, "Starting matchCodeblock at offset %d (%s)", startPos, self.rest.inspect

        # Look for the prefix
        raise MatchFailure, "Did not find prefix: /#{prefix.inspect}/" unless
            self.skip( prefix )
        codePos = self.pointer
        debugMsg 3, "Skipped prefix '%s' to offset %d" %
            [ self.matched, codePos ]

        # Build a regexp for the outer delimiters
        ldelimOuter = "(" + outerDelimPairs.keys  .uniq.collect {|delim| Regexp::quote(delim)}.join('|') + ")"
        rdelimOuter = "(" + outerDelimPairs.values.uniq.collect {|delim| Regexp::quote(delim)}.join('|') + ")"
        debugMsg 4, "Using /%s/ as the outer delim regex" % ldelimOuter

        unless self.scan( ldelimOuter )
            raise MatchFailure, %q:Did not find opening bracket at "%s..." offset %d: %
                [ self.rest[0,20].chomp, codePos ]
        end

        # Look up the corresponding outer delimiter
        closingDelim = outerDelimPairs[self.matched] or
            raise DelimiterError, "Could not find closing delimiter for '%s'" %
                self.matched
        
        debugMsg 3, "Scanning for closing delim '#{closingDelim}'"
        matched = ''
        patvalid = true

        # Scan until the end of the text or until an explicit break
        while self.rest?
            debugMsg 5, "Scanning from offset %d (%s)", self.pointer, self.rest.inspect
            matched = ''

            # Skip comments
            debugMsg 5, "Trying to match a comment"
            if self.scan( /\s*#.*/ )
                debugMsg 4, "Skipping comment '%s' to offset %d" % 
                    [ self.matched, self.pointer ]
                next
            end

            # Look for (any) closing delimiter
            debugMsg 5, "Trying to match a closing outer delimiter with /\s*(#{rdelimOuter})/"
            if self.scan( /\s*(#{rdelimOuter})/ )
                debugMsg 4, "Found a right delimiter '#{self.matched}'"

                # If it's the delimiter we're looking for, stop the scan
                if self.matched.strip == closingDelim
                    matched = self.matched
                    debugMsg 3, "Found the closing delimiter we've been looking for (#{matched.inspect})."
                    break

                # Otherwise, it's an error, as we've apparently seen a closing
                # delimiter without a corresponding opening one.
                else
                    raise MatchFailure,
                        %q:Mismatched closing bracket at "%s..." (offset %s). Expected '%s': %
                        [ self.rest[0,20], self.pointer, closingDelim ]
                end
            end

            # Try to match a variable or a quoted phrase
            debugMsg 5, "Trying to match either a variable or quotelike"
            if self.scanVariable( '\s*' ) || self.scanQuotelike( '\s*', patvalid )
                debugMsg 3, "Matched either a variable or quotelike. Offset now %d" % self.pointer
                patvalid = false
                next
            end

            # Match some operators
            # :TODO: This hasn't really been ruby-ified
            debugMsg 5, "Trying to match an operator"
            if self.scan( %r:\s*([-+*x/%^&|.]=?
                    | [!=]~
                    | =(?!>)
                    | (\*\*|&&|\|\||<<|>>)=?
                    | split|grep|map|return
                    ):x )
                debugMsg 3, "Skipped miscellaneous operator '%s' to offset %d." %
                    [ self.matched, self.pointer ]
                patvalid = true
                next
            end

            # Try to match an embedded codeblock
            debugMsg 5, "Trying to match an embedded codeblock with delim pairs: %s",
                innerDelimPairs.inspect
            if self.scanCodeblock( innerDelimPairs )
                debugMsg 3, "Skipped inner codeblock to offset %d." % self.pointer
                patvalid = true
                next
            end

            # Try to match a stray outer-left delimiter
            debugMsg 5, "Trying to match a stray outer-left delimiter (#{ldelimOuter})"
            if self.match?( ldelimOuter )
                raise MatchFailure, "Improperly nested codeblock at offset %d: %s... " %
                    [ self.pointer, self.rest[0,20] ]
            end

            patvalid = false
            self.scan( /\s*(\w+|[-=>]>|.|\Z)/m )
            debugMsg 3, "Skipped '%s' to offset %d" %
                [ self.matched, self.pointer ]
        end


        unless matched
            raise MatchFailure, "No match found for opening bracket"
        end

        rval = {
            :match  => self.string[codePos .. (self.pointer - 1)],
            :prefix => self.string[startPos, (codePos-startPos)],
            :suffix => self.string[ self.pointer..-1 ],
        }
        debugMsg 1, "matchCodeblock succeeded: %s" % rval.inspect
        return rval
    end


    ### Attempt to derive and return the number of scan methods traversed up to
    ### this point by examining the call stack.
    def scanDepth
        return caller(2).find_all {|frame|
            frame =~ /in `scan(Variable|Tagged|Codeblock|Bracketed|Quotelike)'/
        }.length
    end


    #######
    private
    #######

    ### Print the specified <tt>message</tt> to STDERR if the scanner's
    ### debugging level is greater than or equal to <tt>level</tt>.
    def debugMsg( level, msgFormat, *args )
        return unless level.nonzero? && self.debugLevel >= level
        msg = if args.empty? then msgFormat else format(msgFormat, *args) end
        $stderr.puts( (" " * (level-1) * 2) + msg )
    end


    ### Given a series of one or more bracket characters (eg., '<', '[', '{',
    ### etc.), return the brackets reversed in order and direction.
    def revbracket( bracket )
        return bracket.to_s.reverse.tr( '<[{(', '>]})' )
    end


    ### Given an opening <tt>tag</tt> of the sort matched by #scanTagged,
    ### construct and return a closing tag.
    def makeClosingTag( tag )
        debugMsg 3, "Making a closing tag for '%s'" % tag

        closingTag = tag.gsub( /^([[(<{]+)(#{XmlName}).*/ ) {
            Regexp.quote( "#{$1}/#{$2}" + revbracket($1) )
        }

        raise MatchFailure, "Unable to construct closing tag to match: #{tag}" unless closingTag
        return closingTag
    end


    ### Make and return a new Regexp which matches substrings bounded by the
    ### specified +delimiters+, not counting those which have been escaped with
    ### the escape characters in +escapes+.
    def makeDelimPattern( delimiters, escapes='\\', prefix='\\s*' )
        delimiters = delimiters.to_s
        escapes = escapes.to_s
        
        raise DelimiterError, "Illegal delimiter '#{delimiter}'" unless delimiters =~ /\S/

        # Pad the escapes string to the same length as the delimiters
        escapes.concat( escapes[-1,1] * (delimiters.length - escapes.length) )
        patParts = []
        
        # Escape each delimiter and a corresponding escape character, and then
        # build a pattern part from them
        delimiters.length.times do |i|
            del = Regexp.escape( delimiters[i, 1] )
            esc = Regexp.escape( escapes[i, 1] )

            if del == esc then
                patParts.push "#{del}(?:[^#{del}]*(?:(?:#{del}#{del})[^#{del}]*)*)#{del}"
            else
                patParts.push "#{del}(?:[^#{esc}#{del}]*(?:#{esc}.[^#{esc}#{del}]*)*)#{del}";
            end
        end

        # Join all the parts together and return one big pattern
        return Regexp::new( "#{prefix}(?:#{patParts.join("|")})" )
    end

end # class StringExtractor


