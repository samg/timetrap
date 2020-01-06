module Timetrap
  module Formatters
    class Quota
      SECONDS_PER_DAY = 8 * 60 * 60

      attr_accessor :output
      include Timetrap::Helpers

      def initialize(all_entries)
        output = StringIO.new
        sheets = all_entries.inject({}) do |h, entry|
          h[entry.sheet] ||= []
          h[entry.sheet] << entry
          h
        end

        sheets.each do |sheet_name, sheet_entries|
          output.puts "Timesheet: #{sheet_name}"
          days = sheet_entries.group_by { |e| e.start.to_date }

          days.each do |date, entries|
            output.puts "#{date} #{format_duration(entries.map(&:duration).sum)} #{format_duration(SECONDS_PER_DAY)}"
          end

          logged_duration = sheet_entries.map(&:duration).sum
          expected_duration = days.size * SECONDS_PER_DAY
          output.puts
          output.puts "Total #{format_duration(logged_duration)} #{format_duration(expected_duration)}"
          output.puts "Balance: #{format_duration(logged_duration - expected_duration)}"
        end

        self.output = output.string
      end
    end
  end
end
