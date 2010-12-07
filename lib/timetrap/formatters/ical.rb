begin
  require 'icalendar'
rescue LoadError
  raise <<-ERR
The icalendar gem must be installed for ical output.
To install it:
$ [sudo] gem install icalendar -v"~>1.1.5"
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
        entries.each do |e|
          next unless e.end
          calendar.event do

            # hack around an issue in ical gem in ruby 1.9
            unless respond_to? :<=>
              def <=> other
                dtstart > other.dtstart ? 1 : 0
              end
            end

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
