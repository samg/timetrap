class Timetrap::Formatters::Day
  include Timetrap::Helpers

  DATE_FORMAT = '%Y/%m/%d'

  def initialize(entries)
    @entries = entries
    @total_day_target = hours_to_seconds(Timetrap::Config['day_length_hours'].to_f)
    @width = Timetrap::Config['progress_width'].to_f
  end

  def output
    output = ''
    todays_duration = 0.0
    todays_entries = []
    @entries.each do |entry|
      if is_today(entry[:start], entry[:end])
        todays_duration += entry.duration
        todays_entries << entry
      end
    end
    percentage = ((todays_duration/@total_day_target)*100).to_i
    output << '[' << progress_bar(percentage) << '] ' << percentage.to_s << "%\n"
    output << format_total(todays_entries)
    return output
  end

  def is_today(start_time, end_time)
    return (Date.parse(start_time.strftime(DATE_FORMAT))..Date.parse(end_time.strftime(DATE_FORMAT))) === Date.today
  end
  private :is_today

  def hours_to_seconds(hour_amount)
    return (hour_amount * 60.0 * 60.0)
  end
  private :hours_to_seconds

  def progress_bar(percentage)
    if percentage < 100
      hash_num = (@width/100.0) * percentage
      space_num = @width - hash_num
      return '#' * hash_num << ' ' * space_num
    else
      return '#' * @width
    end
  end
  private :progress_bar

end
