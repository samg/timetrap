module Timetrap
  module Helpers

    def load_formatter(formatter)
      err_msg = "Can't load #{formatter.inspect} formatter."
      begin
        paths = (
          Array(Config['formatter_search_paths']) +
          [ File.join( File.dirname(__FILE__), 'formatters') ]
        )
       if paths.detect do |path|
           begin
             fp = File.join(path, formatter)
             require File.join(path, formatter)
             true
           rescue LoadError
             nil
           end
         end
       else
         raise LoadError, "Couldn't find #{formatter}.rb in #{paths.inspect}"
       end
       Timetrap::Formatters.const_get(formatter.camelize)
      rescue LoadError, NameError => e
        err = e.class.new("#{err_msg} (#{e.message})")
        err.set_backtrace(e.backtrace)
        raise err
      end
    end

    def load_auto_sheet(auto_sheet)
      err_msg = "Can't load #{auto_sheet.inspect} auto_sheet."
      begin
        paths = (
          Array(Config['auto_sheet_search_paths']) +
          [ File.join( File.dirname(__FILE__), 'auto_sheets') ]
        )
       if paths.detect do |path|
           begin
             fp = File.join(path, auto_sheet)
             require File.join(path, auto_sheet)
             true
           rescue LoadError
             nil
           end
         end
       else
         raise LoadError, "Couldn't find #{auto_sheet}.rb in #{paths.inspect}"
       end
       Timetrap::AutoSheets.const_get(auto_sheet.camelize)
      rescue LoadError, NameError => e
        err = e.class.new("#{err_msg} (#{e.message})")
        err.set_backtrace(e.backtrace)
        raise err
      end
    end

    def selected_entries
      ee = if (sheet = sheet_name_from_string(unused_args)) == 'all'
        Timetrap::Entry.filter('sheet not like ? escape "!"', '!_%')
      elsif (sheet = sheet_name_from_string(unused_args)) == 'full'
       Timetrap::Entry.filter()
      elsif sheet =~ /.+/
        Timetrap::Entry.filter('sheet = ?', sheet)
      else
        Timetrap::Entry.filter('sheet = ?', Timer.current_sheet)
      end
      ee = ee.filter('start >= ?', Date.parse(Timer.process_time(args['-s']).to_s)) if args['-s']
      ee = ee.filter('start <= ?', Date.parse(Timer.process_time(args['-e']).to_s) + 1) if args['-e']
      ee
    end

    def format_time time
      return '' unless time.respond_to?(:strftime)
      time.strftime('%H:%M:%S')
    end

    def format_date time
      return '' unless time.respond_to?(:strftime)
      time.strftime('%a %b %d, %Y')
    end

    def format_date_if_new time, last_time
      return '' unless time.respond_to?(:strftime)
      same_day?(time, last_time) ? '' : format_date(time)
    end

    def same_day? time, other_time
      format_date(time) == format_date(other_time)
    end

    def format_seconds secs
      negative = secs < 0
      secs = secs.abs
      formatted = "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
      formatted = "-#{formatted}" if negative
      formatted
    end
    alias :format_duration :format_seconds

    def format_total entries
      secs = entries.inject(0) do |m, e|
        m += e.duration
      end
      "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
    end

    def sheet_name_from_string string
      string = string.strip
      case string
      when /^\W*all\W*$/ then "all"
      when /^\W*full\W*$/ then "full"
      when /^$/ then Timer.current_sheet
      else
        entry = DB[:entries].filter(Sequel.like(:sheet,string)).first ||
          DB[:entries].filter(Sequel.like(:sheet, "#{string}%")).first
        if entry
          entry[:sheet]
        else
          raise "Can't find sheet matching #{string.inspect}"
        end
      end
    end
  end
end
