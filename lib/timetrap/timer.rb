module Timetrap
  module Timer
    class AlreadyRunning < StandardError
      def message
        "Timetrap is already running"
      end
    end

    extend self

    def current_sheet= sheet
      m = Meta.find_or_create(:key => 'current_sheet')
      m.value = sheet
      m.save
    end

    def current_sheet
      unless Meta.find(:key => 'current_sheet')
        Meta.create(:key => 'current_sheet', :value => 'default')
      end
      Meta.find(:key => 'current_sheet').value
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
