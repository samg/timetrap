class Timetrap::Formatters::Timetext
  attr_accessor :output
  include Timetrap::Helpers

  def initialize entries
    self.output = ''
    sheets = entries.inject({}) do |h, e|
      date = Date.new(e.start.year, e.start.month, e.start.day)
      h[date] ||= []
      h[date] << e
      h
    end
    (dates = sheets.keys.sort).each do |date|
      self.output <<  "Day: #{date}\n"
      id_heading = Timetrap::CLI.args['-v'] ? 'Id' : '  '
      self.output <<  "#{id_heading}  Sheet                Start      End        Duration   Notes\n"
      last_sheet = nil
      from_current_day = []
      sheets[date].each_with_index do |e, i|
        from_current_day << e
        self.output <<  "%-4s%16s%11s -%9s%10s    %s\n" % [
          (Timetrap::CLI.args['-v'] ? e.id : ''),
          e.sheet == last_sheet ? '' : e.sheet,
          format_time(e.start),
          format_time(e.end),
          format_duration(e.duration),
          e.note
        ]

        nxt = sheets[date].to_a[i+1]
        if nxt == nil or e.sheet != nxt.sheet
          self.output <<  "%52s\n" % format_total(from_current_day)
          from_current_day = []
        else
        end
        last_sheet = e.sheet
      end
      self.output <<  <<-OUT
    ---------------------------------------------------------
      OUT
      self.output <<  "    Total%43s\n" % format_total(sheets[date])
      self.output <<  "\n" unless date == dates.last
    end
    if sheets.size > 1
      self.output <<  <<-OUT
-------------------------------------------------------------
      OUT
      self.output <<  "Grand Total%41s\n" % format_total(sheets.values.flatten)
    end
  end
end
