module Timetrap
  class Entry < Sequel::Model
    plugin :schema

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
      self[:start]= process_time(time)
    end

    def end= time
      self[:end]= process_time(time)
    end

    def start
      round? ? rounded_start : self[:start]
    end

    def end
      round? ? rounded_end : self[:end]
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
    def process_time(time)
      case time
      when Time
        time
      when String
        if parsed = Chronic.parse(time)
          parsed
        elsif safe_for_time_parse?(time) and parsed = Time.parse(time)
          parsed
        else
          CLI.say "Could not parse #{time.inspect}, defaulting to now"
          Time.now
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


    # do a quick pseudo migration.  This should only get executed on the first run
    set_schema do
      primary_key :id
      column :note, :string
      column :start, :timestamp
      column :end, :timestamp
      column :sheet, :string
    end
    create_table unless table_exists?
  end

  class Meta < Sequel::Model(:meta)
    plugin :schema

    set_schema do
      primary_key :id
      column :key, :string
      column :value, :string
    end
    create_table unless table_exists?
  end
end
