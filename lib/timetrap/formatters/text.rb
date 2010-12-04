module Timetrap
  module Formatters
    class Text
      attr_accessor :to_s
      include Timetrap::Helpers

      def initialize entries
        self.to_s = ''
        sheets = entries.inject({}) do |h, e|
          h[e.sheet] ||= []
          h[e.sheet] << e
          h
        end
        (sheet_names = sheets.keys.sort).each do |sheet|
          self.to_s <<  "Timesheet: #{sheet}\n"
          id_heading = Timetrap::CLI.args['-v'] ? 'Id' : '  '
          self.to_s <<  "#{id_heading}  Day                Start      End        Duration   Notes\n"
          last_start = nil
          from_current_day = []
          sheets[sheet].each_with_index do |e, i|
            from_current_day << e
            e_end = e.end_or_now
            self.to_s <<  "%-4s%16s%11s -%9s%10s    %s\n" % [
              (Timetrap::CLI.args['-v'] ? e.id : ''),
              format_date_if_new(e.start, last_start),
              format_time(e.start),
              format_time(e.end),
              format_duration(e.start, e_end),
              e.note
            ]

            nxt = sheets[sheet].to_a[i+1]
            if nxt == nil or !same_day?(e.start, nxt.start)
              self.to_s <<  "%52s\n" % format_total(from_current_day)
              from_current_day = []
            else
            end
            last_start = e.start
          end
          self.to_s <<  <<-OUT
    ---------------------------------------------------------
          OUT
          self.to_s <<  "    Total%43s\n" % format_total(sheets[sheet])
          self.to_s <<  "\n" unless sheet == sheet_names.last
        end
        if sheets.size > 1
          self.to_s <<  <<-OUT
-------------------------------------------------------------
          OUT
          self.to_s <<  "Grand Total%41s\n" % format_total(sheets.values.flatten)
        end
      end
    end
  end
end
