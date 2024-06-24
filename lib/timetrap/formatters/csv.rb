module Timetrap
  module Formatters
    class Csv
      attr_reader :output

      def initialize entries
        @output = entries.inject(Timetrap::CLI.args['-v'] ? "id,start,end,note,sheet\n" : "start,end,note,sheet\n") do |out, e|
          next(out) unless e.end
          if Timetrap::CLI.args['-v']
            out << %|"#{e.id}",|
          end
          out << %|"#{e.start.strftime(time_format)}","#{e.end.strftime(time_format)}","#{e.note}","#{e.sheet}"\n|
        end
      end

      private
      def time_format
        "%Y-%m-%d %H:%M:%S"
      end

      def escape(note)
        note.gsub %q{"}, %q{""}
      end
    end
  end
end
