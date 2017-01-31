require '/usr/local/lib/ruby/gems/1.8/gems/timetrap-1.7.1/lib/timetrap/formatters/text'

module Timetrap
  module Formatters
    class Decdur < Text
      def format_duration t1, t2
        secs = t2 - t1
        format_decimal secs
      end

      def hour_decimal_from_seconds secs
        secs/3600.0
      end

      def format_decimal secs
        hour = hour_decimal_from_seconds secs
        "%.2f" % hour
      end

      def format_total entries
        secs = entries.inject(0) do |m, e|
          m += e.duration
        end 
        format_decimal secs
      end 
    end
  end
end
