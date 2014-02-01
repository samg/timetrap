module Timetrap
  module Timer
    extend Helpers::AutoLoad

    class AlreadyRunning < StandardError
      def message
        "Timetrap is already running"
      end
    end

    extend self

    def process_time(time, now = Time.now)
      case time
      when Time
        time
      when String
        chronic = begin
          time_closest_to_now_with_chronic(time, now)
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

    def time_closest_to_now_with_chronic(time, now)
      [
        Chronic.parse(time, :context => :past, :now => now),
        Chronic.parse(time, :context => :future, :now => now)
      ].sort_by{|a| (a.to_i - now.to_i).abs }.first
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

      if the_auto_sheet = auto_sheet
        unless @auto_sheet_warned
          warn "Sheet #{the_auto_sheet.inspect} selected by Timetrap::AutoSheets::#{::Timetrap::Config['auto_sheet'].capitalize}"
          @auto_sheet_warned = true
        end
        the_auto_sheet
      else
        Meta.find(:key => 'current_sheet').value
      end
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

    # the last entry to be checked out of
    def last_checkout
      meta = Meta.find(:key => 'last_checkout_id')
      Entry[meta.value] if meta
    end

    def running_entries
      Entry.filter(:end => nil)
    end

    def stop_all(time = nil)
      running_entries.map{ |e| stop(e, time) }
    end

    def stop sheet_or_entry, time = nil
      a = case sheet_or_entry
      when Entry
        sheet_or_entry
      when String
        active_entry(sheet_or_entry)
      end

      if a
        time ||= Time.now
        a.end = time
        a.save
        meta = Meta.find(:key => 'last_checkout_id') || Meta.create(:key => 'last_checkout_id')
        meta.value = a.id
        meta.save
      end
      a
    end

    def start note, time = nil
      raise AlreadyRunning if running?
      time ||= Time.now
      Entry.create(:sheet => Timer.current_sheet, :note => note, :start => time).save
    end

    def auto_sheet
      if Timetrap::Config['auto_sheet']
        load_auto_sheet(Config['auto_sheet']).new.sheet
      end
    end
  end
end
