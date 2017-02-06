begin
  require 'json'
rescue LoadError
  raise <<-ERR
The json gem must be installed for json output.
To install it:
$ [sudo] gem install json -v"~>1.4.6"
  ERR
end

module Timetrap
  module Formatters
    class Json
      attr_accessor :output
      include Timetrap::Helpers

      def initialize entries
        @entries = entries
        sheets = entries.inject({}) do |h, e|
          h[e.sheet] ||= []
          h[e.sheet] << e
          h
        end
        @content = {}
        @content_sheets = []
        @sheets_total = 0
        (sheet_names = sheets.keys.sort).each do |sheet|
          @content_sheet = {"name":sheet}
          @content_entries = []
          @sheet_total = 0
          sheets[sheet].each_with_index do |e, i|
            next if e.end.nil?
            @content_entry = {}
            @content_entry["end"] = e.end
            @content_entry["start"] = e.start
            @content_entry["note"] = e.note
            @content_entry["id"] = e.id
            @content_entry["duration"] = format_duration(e.duration).lstrip
            @sheet_total = @sheet_total + e.duration
            @content_entries << @content_entry
          end
          @content_sheet["sheet_time"] = format_duration(@sheet_total).lstrip

          @content_sheet["entries"] = @content_entries.compact
          @content_sheets << @content_sheet
          @sheets_total = @sheets_total + @sheet_total

        end
        @content["sheets"] = @content_sheets
        @content["total_time"] = format_duration(@sheets_total).lstrip
        #puts "J: #{@content.to_json}"
        @output = @content.to_json
      end
    end
  end
end
