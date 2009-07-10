require 'icalendar'
require 'date'
module Timetrap
  module Formatters
    class Ical
      include Icalendar
      def calendar
        @calendar ||= Calendar.new
      end

      def output
        calendar.to_ical
      end

      def initialize entries
        entries.each do |e|
          next unless e.end
          calendar.event do
            dtstart DateTime.parse(e.start.to_s)
            dtend DateTime.parse(e.end.to_s)
            summary e.note
            description e.note
          end
        end
        calendar.publish
      end
    end
  end
end
