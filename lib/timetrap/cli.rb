module Timetrap
  module CLI
    extend Helpers
    attr_accessor :args
    extend self

    USAGE = <<-EOF

Timetrap - Simple Time Tracking

Usage: #{File.basename $0} COMMAND [OPTIONS] [ARGS...]

where COMMAND is one of:
  * backend - open an sqlite shell to the database
    usage: t backend
  * display - display the current timesheet or a specific. Pass `all' as
      SHEET to display all sheets.
    usage: t display [--ids] [--start DATE] [--end DATE] [--format FMT] [SHEET | all]
    -v, --ids                 Print database ids (for use with edit)
    -s, --start <date:qs>     Include entries that start on this date or later
    -e, --end <date:qs>       Include entries that start on this date or earlier
    -f, --format <format>     The output format.  Currently supports ical and
                                text (default).
  * edit - alter an entry's note, start, or end time. Defaults to the active entry
    usage: t edit [--id ID] [--start TIME] [--end TIME] [NOTES]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
    -s, --start <time:qs>     Change the start time to <time>
    -e, --end <time:qs>       Change the end time to <time>
  * format - alias for display
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
    usage: t running
  * switch - switch to a new timesheet
    usage: t switch TIMESHEET
  * week - shortcut for display with start date set to monday of this week
    usage: t week [--ids] [--end DATE] [--format FMT] [SHEET | all]

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

    def say *something
      puts *something
    end

    def invoke_command_if_valid
      command = args.unused.shift
      case (valid = commands.select{|name| name =~ %r|^#{command}|}).size
      when 0 then say "Invalid command: #{command}"
      when 1 then send valid[0]
      else; say "Ambigous command: #{command}"; end
    end

    def edit
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
      begin
        fmt_klass = if args['-f']
          Timetrap::Formatters.const_get("#{args['-f'].classify}")
        else
          Timetrap::Formatters::Text
        end
      rescue
        say "Invalid format specified `#{args['-f']}'"
        return
      end
      ee = if (sheet = sheet_name_from_string(unused_args)) == 'all'
        Timetrap::Entry
      elsif sheet =~ /.+/
        Timetrap::Entry.filter(:sheet => sheet)
      else
        Timetrap::Entry.filter(:sheet => Timetrap.current_sheet)
      end
      ee = ee.filter(:start >= Date.parse(args['-s'])) if args['-s']
      ee = ee.filter(:start <= Date.parse(args['-e']) + 1) if args['-e']
      say Timetrap.format(fmt_klass, ee.order(:start).all)
    end

    # TODO: Consolidate display and format
    def format
      begin
        fmt_klass = Timetrap::Formatters.const_get("#{args['-f'].classify}")
      rescue
        say "Invalid format specified `#{args['-f']}'"
        return
      end
      ee = if (sheet = sheet_name_from_string(unused_args)) == 'all'
        Timetrap::Entry
      elsif sheet =~ /.+/
        Timetrap::Entry.filter(:sheet => sheet)
      else
        Timetrap::Entry.filter(:sheet => Timetrap.current_sheet)
      end
      ee = ee.filter(:start >= Date.parse(args['-s'])) if args['-s']
      ee = ee.filter(:start <= Date.parse(args['-e']) + 1) if args['-e']
      say Timetrap.format(fmt_klass, ee.all)
    end

    def switch
      sheet = unused_args
      if not sheet =~ /.+/ then say "No sheet specified"; return end
      say "Switching to sheet " + Timetrap.switch(sheet)
    end

    def list
      sheets = Entry.sheets.map do |sheet|
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
      say "Running Timesheets:"
      say Timetrap::Entry.filter(:end => nil).map{|e| "  #{e.sheet}: #{e.note}"}.uniq.sort
    end

    def week
      args['-s'] = Date.today.wday == 1 ? Date.today.to_s : Date.parse(Chronic.parse(%q(last monday)).to_s).to_s
      display
    end

    private

    def unused_args
      args.unused.join(' ')
    end

  end
end
