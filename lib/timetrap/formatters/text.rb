module Timetrap
  module Formatters
    class Text
      LONGEST_NOTE_LENGTH = 50
      attr_accessor :output
      include Timetrap::Helpers

      def initialize entries
        @entries = entries
        self.output = ""
        sheets = entries.each_with_object({}) do |e, h|
          h[e.sheet] ||= []
          h[e.sheet] << e
        end

        (sheet_names = sheets.keys.sort).each do |sheet|
          output << "Timesheet: #{sheet}\n"
          id_heading = Timetrap::CLI.args["-v"] ? "Id#{" " * (max_id_length - 3)}" : "  "
          output << "#{id_heading}  Day                Start      End        Duration   Notes\n"
          last_start = nil
          from_current_day = []

          sheets[sheet].each_with_index do |e, i|
            from_current_day << e
            output << "%-#{max_id_length + 1}s%16s%11s -%9s%10s    %s\n" % [
              (Timetrap::CLI.args["-v"] ? e.id : ""),
              format_date_if_new(e.start, last_start),
              format_time(e.start),
              format_time(e.end),
              format_duration(e.duration),
              format_note(e.note)
            ]

            nxt = sheets[sheet].to_a[i + 1]
            if nxt.nil? || !same_day?(e.start, nxt.start)
              output << "%#{49 + max_id_length}s\n" % format_total(from_current_day)
              from_current_day = []
            end
            last_start = e.start
          end
          output << "#{" " * (max_id_length + 1)}%s\n" % ("-" * (52 + longest_note))
          output << "#{" " * (max_id_length + 1)}Total%43s\n" % format_total(sheets[sheet])
          output << "\n" unless sheet == sheet_names.last
        end
        if sheets.size > 1
          output << "%s\n" % ("-" * (4 + 52 + longest_note))
          output << "Grand Total%41s\n" % format_total(sheets.values.flatten)
        end
      end

      private

      attr_reader :entries

      def longest_note
        @longest_note ||= entries.inject("Notes".length) { |l, e| [e.note.to_s.rstrip.length, LONGEST_NOTE_LENGTH].min }
      end

      def max_id_length
        @max_id_length ||= if Timetrap::CLI.args["-v"]
          entries.inject(3) { |l, e| [e.id.to_s.length, l].max }
        else
          3
        end
      end

      def word_wrap(text, line_width: LONGEST_NOTE_LENGTH, break_sequence: "\n")
        # https://github.com/rails/rails/blob/df63abe6d31cdbe426ff6dda9bdd878acc602728/actionview/lib/action_view/helpers/text_helper.rb#L258-L262

        text.split("\n").collect! do |line|
          line.length > line_width ? line.gsub(/(.{1,#{line_width}})(\s+|$)/, "\\1#{break_sequence}").strip : line
        end * break_sequence
      end

      def format_note(note)
        return "" unless note
        wrapped_note = word_wrap(note.tr("\n", " "))
        lines = []
        wrapped_note.lines.each_with_index do |line, index|
          lines << padded_line(line.strip, index)
        end

        lines.join("\n")
      end

      def padded_line(content, line_number)
        return content if line_number == 0
        "#{" " * (56 + max_id_length - 3)}#{content}"
      end
    end
  end
end
