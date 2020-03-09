module Timetrap
  class Entry < Sequel::Model
    class << self
    # a class level instance variable that controls whether or not all entries
    # should respond to #start and #end with times rounded to 15 minute
    # increments.
      attr_accessor :round
    end

    def round?
      !!self.class.round
    end

    def start= time
      self[:start]= Timer.process_time(time)
    end

    def end= time
      self[:end]= Timer.process_time(time)
    end

    def start
      round? ? rounded_start : self[:start]
    end

    def end
      round? ? rounded_end : self[:end]
    end

    def sheet
      self[:sheet].to_s
    end

    def duration
      @duration ||= self.end_or_now.to_i - self.start.to_i
    end
    def duration=( nd )
      @duration = nd.to_i
    end

    def end_or_now
      self.end || (round? ? round(Time.now) : Time.now)
    end

    def rounded_start
      round(self[:start])
    end

    def rounded_end
      round(self[:end])
    end

    def round time
      return nil unless time
      Time.at(
        if (r = time.to_i % Timetrap::Config['round_in_seconds']) < 450
          time.to_i - r
        else
          time.to_i + (Timetrap::Config['round_in_seconds'] - r)
        end
      )
    end

    def self.sheets
      map{|e|e.sheet}.uniq.sort
    end

    private

  end

  class Meta < Sequel::Model(:meta)
    def value
      self[:value].to_s
    end
  end
end
