module Timetrap
  module Formatters
  class Timetrap::Formatters::Datesheet
      attr_accessor :output
      include Timetrap::Helpers

	  def time_format
			  "%Y-%m-%d"
	  end	  

      def initialize entries
        self.output = ''
        sheets = entries.inject({}) do |h, e|
          h[e.sheet] ||= []
          h[e.sheet] << e
          h
        end
        (sheet_names = sheets.keys.sort).each do |sheet|
          id_heading = Timetrap::CLI.args['-v'] ? 'Id' : '  '
          last_start = nil
          from_current_day = []
          sheets[sheet].each_with_index do |e, i|
            from_current_day << e
           e_end = e.end_or_now
            self.output <<  "%1s%10s%11s -%9s%10s  [%s]  %s\n" % [
              (Timetrap::CLI.args['-v'] ? e.id : ''),
              e.start.strftime(time_format),
			  format_time(e.start),
              format_time(e.end),
             format_duration(e.duration),
              e.sheet,
			  e.note
            ]

            nxt = sheets[sheet].to_a[i+1]
            if nxt == nil or !same_day?(e.start, nxt.start)
              from_current_day = []
            else
            end
            last_start = e.start
          end
        end
        if sheets.size > 1
       	end
        
	  end
    end
  end
end
