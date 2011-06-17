module Timetrap
  module Timer
    class AlreadyRunning < StandardError
      def message
        "Timetrap is already running"
      end
    end

    extend self

    def process_time(time)
      case time
      when Time
        time
      when String
        chronic = begin
          Chronic.parse(time)
        rescue => e
          warn "#{e.class} in Chronic gem parsing time.  Falling back to Time.parse"
        end

        if parsed = chronic
          parsed
        elsif safe_for_time_parse?(time) and parsed = Time.parse(time)
          parsed
        else
          raise ArgumentError, "Could not parse #{time.inspect}, entry not updated"
        end
      end
    end

    # Time.parse is optimistic and will parse things like '=18' into midnight
    # on 18th of this month.
    # It will also turn 'total garbage' into Time.now
    # Here we do some sanity checks on the string to protect it from common
    # cli formatting issues, and allow reasonable warning to be passed back to
    # the user.
    def safe_for_time_parse?(string)
      # misformatted cli option
      !string.include?('=') and
      # a date time string needs a number in it
      string =~ /\d/
    end

    def current_sheet= sheet
      last = Meta.find_or_create(:key => 'last_sheet')
      last.value = current_sheet
      last.save

      m = Meta.find_or_create(:key => 'current_sheet')
      m.value = sheet
      m.save
    end

    def current_sheet
      unless Meta.find(:key => 'current_sheet')
        Meta.create(:key => 'current_sheet', :value => 'default')
      end
      Meta.find(:key => 'current_sheet').value.to_s
    end

    def last_sheet
      m = Meta.find(:key => 'last_sheet')
      m and m.value
    end

    def entries sheet = nil
      Entry.filter(:sheet => sheet).order_by(:start)
    end

    def running?
      !!active_entry
    end

    def active_entry(sheet=nil)
      Entry.find(:sheet => (sheet || Timer.current_sheet), :end => nil)
    end

    def running_entries
      Entry.filter(:end => nil)
    end

    def stop sheet, time = nil
      if a = active_entry(sheet)
        time ||= Time.now
        a.end = time
        a.save
      end
    end

    def start note, time = nil
      raise AlreadyRunning if running?
      time ||= Time.now
      Entry.create(:sheet => Timer.current_sheet, :note => note, :start => time).save
    end

  end
end
