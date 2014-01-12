module Timetrap
  module Formatters
    class Text
      attr_accessor :output
      include Timetrap::Helpers

      def initialize entries
        self.output = ''
        sheets = entries.inject({}) do |h, e|
          h[e.sheet] ||= []
          h[e.sheet] << e
          h
        end
        longest_note = entries.inject('Notes'.length) {|l, e| [e.note.to_s.rstrip.length, l].max}
        max_id_length = if Timetrap::CLI.args['-v']
          entries.inject(3) {|l, e| [e.id.to_s.length, l].max}
        else
          3
        end
        (sheet_names = sheets.keys.sort).each do |sheet|

          self.output <<  "Timesheet: #{sheet}\n"
          id_heading = Timetrap::CLI.args['-v'] ? "Id#{' ' * (max_id_length - 3)}" : "  "
          self.output <<  "#{id_heading}  Day                Start      End        Duration   Notes\n"
          last_start = nil
          from_current_day = []


          sheets[sheet].each_with_index do |e, i|
            from_current_day << e
            self.output <<  "%-#{max_id_length + 1}s%16s%11s -%9s%10s    %s\n" % [
              (Timetrap::CLI.args['-v'] ? e.id : ''),
              format_date_if_new(e.start, last_start),
              format_time(e.start),
              format_time(e.end),
              format_duration(e.duration),
              e.note
            ]

            nxt = sheets[sheet].to_a[i+1]
            if nxt == nil or !same_day?(e.start, nxt.start)
              self.output <<  "%#{49 + max_id_length}s\n" % format_total(from_current_day)
              from_current_day = []
            else
            end
            last_start = e.start
          end
          self.output <<  "#{' ' * (max_id_length + 1)}%s\n" % ('-'*(52+longest_note))
          self.output <<  "#{' ' * (max_id_length + 1)}Total%43s\n" % format_total(sheets[sheet])
          self.output <<  "\n" unless sheet == sheet_names.last
        end
        if sheets.size > 1
          self.output <<  "%s\n" % ('-'*(4+52+longest_note))
          self.output <<  "Grand Total%41s\n" % format_total(sheets.values.flatten)
        end
      end
    end
  end
end
