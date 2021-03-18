begin
  require 'icalendar'
rescue LoadError
  raise <<-ERR
The icalendar gem must be installed for ical output.
To install it:
$ [sudo] gem install icalendar
  ERR
end

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
        entries.each do |entry|
          next unless entry.end
          calendar.event do |e|
            e.dtstart = DateTime.parse(entry.start.to_s)
            e.dtend = DateTime.parse(entry.end.to_s)
            e.summary = entry.note
            e.description = entry.note
          end
        end
        calendar.publish
      end
    end
  end
end
