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

    def selected_entries
      ee = if (sheet = sheet_name_from_string(unused_args)) == 'all'
        Timetrap::Entry.filter('sheet not like ? escape "!"', '!_%')
      elsif sheet =~ /.+/
        Timetrap::Entry.filter('sheet = ?', sheet)
      else
        Timetrap::Entry.filter('sheet = ?', Timer.current_sheet)
      end
      ee = ee.filter('start >= ?', Date.parse(Chronic.parse(args['-s']).to_s)) if args['-s']
      ee = ee.filter('start <= ?', Date.parse(Chronic.parse(args['-e']).to_s) + 1) if args['-e']
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

    def format_duration stime, etime
      return '' unless stime and etime
      secs = etime.to_i - stime.to_i
      format_seconds secs
    end

    def format_seconds secs
      "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
    end

    def format_total entries
      secs = entries.inject(0){|m, e|e_end = e.end_or_now; m += e_end.to_i - e.start.to_i if e_end && e.start;m}
      "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
    end

    def sheet_name_from_string string
      string = string.strip
      case string
      when /^\W*all\W*$/ then "all"
      when /^$/ then Timer.current_sheet
      else
        entry = DB[:entries].filter(:sheet.like("#{string}")).first ||
          DB[:entries].filter(:sheet.like("#{string}%")).first
        if entry
          entry[:sheet]
        else
          raise "Can't find sheet matching #{string.inspect}"
        end
      end
    end
  end
end
