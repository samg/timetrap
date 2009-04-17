require 'rubygems'
require 'chronic'
require 'sequel'
require 'Getopt/Declare'
# connect to database.  This will create one if it doesn't exist
DB_NAME = defined?(TEST_MODE) ? nil : "#{ENV['HOME']}/.timetrap.db"
DB = Sequel.sqlite DB_NAME

module Timetrap
  extend self

  module CLI
    attr_accessor :args
    extend self

    USAGE = <<-EOF

Timetrap - Simple Time Tracking

Usage: #{File.basename $0} COMMAND [OPTIONS] [ARGS...]

where COMMAND is one of:
  * alter - alter an entry's note, start, or end time. Defaults to the active entry
    usage: t alter [--id ID] [--start TIME] [--end TIME] [NOTES]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
    -s, --start <time:qs>     Change the start time to <time>
    -e, --end <time:qs>       Change the end time to <time>
  * backend - open an sqlite shell to the database
    usage: t backend
  * display - display the current timesheet
    usage: t display [--ids] [TIMESHEET]
    -v, --ids                 Print database ids (for use with alter)
  * format - export a sheet to csv format
    NOT IMPLEMENTED
  * in - start the timer for the current timesheet
    usage: t in [--at TIME] [NOTES]
    -a, --at <time:qs>        Use this time instead of now
  * kill - delete a timesheet
    usage: t kill [--id ID] [TIMESHEET]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
  * list - show the available timesheets
    usage: t list
  * now - show the status of the current timesheet
    usage: t now
  * out - stop the timer for the current timesheet
    usage: t out [--at TIME]
    -a, --at <time:qs>        Use this time instead of now
  * running - show all running timesheets
    NOT IMPLEMENTED
  * switch - switch to a new timesheet
    usage: t switch TIMESHEET

    OTHER OPTIONS
    -h, --help     Display this help
    EOF

    def parse arguments
      args.parse arguments
    end

    def invoke
      args['-h'] ? say(USAGE) : invoke_command_if_valid
    end

    def commands
      Timetrap::CLI::USAGE.scan(/\* \w+/).map{|s| s.gsub(/\* /, '')}
    end

    def invoke_command_if_valid
      command = args.unused.shift
      case (valid = commands.select{|name| name =~ %r|^#{command}|}).size
      when 0 then say "Invalid command: #{command}"
      when 1 then send valid[0]
      else; say "Ambigous command: #{command}"; end
    end

    def alter
      entry = args['-i'] ? Entry[args['-i']] : Timetrap.active_entry
      say "can't find entry" && return unless entry
      entry.update :start => args['-s'] if args['-s'] =~ /.+/
      entry.update :end => args['-e'] if args['-e'] =~ /.+/
      entry.update :note => unused_args if unused_args =~ /.+/
    end

    def backend
      exec "sqlite3 #{DB_NAME}"
    end

    def in
      Timetrap.start unused_args, args['-a']
    end

    def out
      Timetrap.stop args['-a']
    end

    def kill
      if e = Entry[args['-i']]
        out = "are you sure you want to delete entry #{e.id}? "
        out << "(#{e.note}) " if e.note.to_s =~ /.+/
        print out
        if $stdin.gets =~ /\Aye?s?\Z/i
          e.destroy
          say "it's dead"
        else
          say "will not kill"
        end
      elsif (sheets = Entry.map{|e| e.sheet }.uniq).include?(sheet = unused_args)
        victims = Entry.filter(:sheet => sheet).count
        print "are you sure you want to delete #{victims} entries on sheet #{sheet.inspect}? "
        if $stdin.gets =~ /\Aye?s?\Z/i
          Timetrap.kill_sheet sheet
          say "killed #{victims} entries"
        else
          say "will not kill"
        end
      else
        victim = args['-i'] ? args['-i'].to_s.inspect : sheet.inspect
        say "can't find #{victim} to kill", 'sheets:', *sheets
      end
    end

    def display
      sheet = sheet_name_from_string(unused_args)
      sheet = (sheet =~ /.+/ ? sheet : Timetrap.current_sheet)
      say "Timesheet: #{sheet}"
      id_heading = args['-v'] ? 'Id' : '  '
      say "#{id_heading}  Day                Start      End        Duration   Notes"
      last_start = nil
      from_current_day = []
      (ee = Timetrap.entries(sheet)).each_with_index do |e, i|


        from_current_day << e
        e_end = e.end || Time.now
        say "%-4s%16s%11s -%9s%10s    %s" % [
          (args['-v'] ? e.id : ''),
          format_date_if_new(e.start, last_start),
          format_time(e.start),
          format_time(e.end),
          format_duration(e.start, e_end),
          e.note
        ]

        nxt = Timetrap.entries(sheet).map[i+1]
        if nxt == nil or !same_day?(e.start, nxt.start)
          say "%52s" % format_total(from_current_day)
          from_current_day = []
        else
        end
        last_start = e.start
      end
      say <<-OUT
    ---------------------------------------------------------
      OUT
      say "    Total%43s" % format_total(ee)
    end

    def format
      say "Sorry not implemented yet :-("
    end

    def switch
      sheet = args.unused.join(' ')
      if not sheet =~ /.+/ then say "No sheet specified"; return end
      say "Switching to sheet " + Timetrap.switch(sheet)
    end

    def list
      sheets = Entry.map{|e|e.sheet}.uniq.sort.map do |sheet|
        sheet_atts = {:total => 0, :running => 0, :today => 0}
        DB[:entries].filter(:sheet => sheet).inject(sheet_atts) do |m, e|
          e_end = e[:end] || Time.now
          m[:name] ||= sheet
          m[:total] += (e_end.to_i - e[:start].to_i)
          m[:running] += (e_end.to_i - e[:start].to_i) unless e[:end]
          m[:today] += (e_end.to_i - e[:start].to_i) if same_day?(Time.now, e[:start])
          m
        end
      end
      width = sheets.sort_by{|h|h[:name].length }.last[:name].length + 4
      say " %-#{width}s%-12s%-12s%s" % ["Timesheet", "Running", "Today", "Total Time"]
      sheets.each do |sheet|
        star = sheet[:name] == Timetrap.current_sheet ? '*' : ' '
        say "#{star}%-#{width}s%-12s%-12s%s" % [
          sheet[:running],
          sheet[:today],
          sheet[:total]
        ].map(&method(:format_seconds)).unshift(sheet[:name])
      end
    end

    def now
      if Timetrap.running?
        out = "#{Timetrap.current_sheet}: #{format_duration(Timetrap.active_entry.start, Time.now)}".gsub(/  /, ' ')
        out << " (#{Timetrap.active_entry.note})" if Timetrap.active_entry.note =~ /.+/
        say out
      else
        say "#{Timetrap.current_sheet}: not running"
      end
    end

    def running
      say "Sorry not implemented yet :-("
    end

    private

    def format_time time
      return '' unless time.respond_to?(:strftime)
      time.strftime('%H:%M:%S')
    end

    def format_date time
      return '' unless time.respond_to?(:strftime)
      time.strftime('%a %b %d, %Y')
    end

    def format_date_if_new time, last_time
      return '' unless time.respond_to?(:strftime)
      same_day?(time, last_time) ? '' : format_date(time)
    end

    def same_day? time, other_time
      format_date(time) == format_date(other_time)
    end

    def format_duration stime, etime
      return '' unless stime and etime
      secs = etime.to_i - stime.to_i
      format_seconds secs
    end

    def format_seconds secs
      "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
    end

    def format_total entries
      secs = entries.inject(0){|m, e|e_end = e.end || Time.now; m += e_end.to_i - e.start.to_i if e_end && e.start;m}
      "%2s:%02d:%02d" % [secs/3600, (secs%3600)/60, secs%60]
    end

    def sheet_name_from_string string
      return "" unless string =~ /.+/
      DB[:entries].filter(:sheet.like("#{string}%")).first[:sheet]
    rescue
      ""
    end

    def unused_args
      args.unused.join(' ')
    end

    public
    def say *something
      puts *something
    end
  end

  def current_sheet= sheet
    m = Meta.find_or_create(:key => 'current_sheet')
    m.value = sheet
    m.save
  end

  def current_sheet
    unless Meta.find(:key => 'current_sheet')
      Meta.create(:key => 'current_sheet', :value => 'default')
    end
    Meta.find(:key => 'current_sheet').value
  end

  def entries sheet = nil
    Entry.filter(:sheet => sheet).order_by(:start)
  end

  def running?
    !!active_entry
  end

  def active_entry
    Entry.find(:sheet => Timetrap.current_sheet, :end => nil)
  end

  def stop time = nil
    while a = active_entry
      time ||= Time.now
      a.end = time
      a.save
    end
  end

  def start note, time = nil
    raise AlreadyRunning if running?
    time ||= Time.now
    Entry.create(:sheet => Timetrap.current_sheet, :note => note, :start => time).save
  rescue => e
    CLI.say e.message
  end

  def switch sheet
    self.current_sheet = sheet
  end

  def kill_sheet sheet
    Entry.filter(:sheet => sheet).destroy
  end

  class AlreadyRunning < StandardError
    def message
      "Timetrap is already running"
    end
  end


  class Entry < Sequel::Model
    plugin :schema

    def start= time
      self[:start]= Chronic.parse(time) || time
    end

    def end= time
      self[:end]= Chronic.parse(time) || time
    end

    # do a quick pseudo migration.  This should only get executed on the first run
    set_schema do
      primary_key :id
      column :note, :string
      column :start, :timestamp
      column :end, :timestamp
      column :sheet, :string
    end
    create_table unless table_exists?
  end

  class Meta < Sequel::Model(:meta)
    plugin :schema

    set_schema do
      primary_key :id
      column :key, :string
      column :value, :string
    end
    create_table unless table_exists?
  end
  CLI.args = Getopt::Declare.new(<<-EOF)
    #{CLI::USAGE}
  EOF
end
