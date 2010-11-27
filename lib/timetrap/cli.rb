module Timetrap
  module CLI
    extend Helpers
    attr_accessor :args
    extend self

    USAGE = <<-EOF

Timetrap - Simple Time Tracking

Usage: #{File.basename $0} COMMAND [OPTIONS] [ARGS...]

COMMAND can be abbreviated. For example `t in` and `t i` are equivalent.

COMMAND is one of:

  * archive - Move entries to a hidden sheet (by default named '_[SHEET]') so
      they're out of the way.
    usage: t archive [--start DATE] [--end DATE] [SHEET]
    -s, --start <date:qs>     Include entries that start on this date or later
    -e, --end <date:qs>       Include entries that start on this date or earlier

  * backend - Open an sqlite shell to the database.
    usage: t backend

  * configure - Write out a config file. print path to config file.
    usage: t configure
    Currently supported options are:
      round_in_seconds:       The duration of time to use for rounding with
                              the -r flag
      database_file:          The file path of the sqlite database
      append_notes_delimiter: delimiter used when appending notes via
                              t edit --append

  * display - Display the current timesheet or a specific. Pass `all' as
      SHEET to display all sheets.
    usage: t display [--ids] [--start DATE] [--end DATE] [--format FMT] [SHEET | all]
    -v, --ids                 Print database ids (for use with edit)
    -s, --start <date:qs>     Include entries that start on this date or later
    -e, --end <date:qs>       Include entries that start on this date or earlier
    -f, --format <format>     The output format.  Currently supports ical, csv, and
                                text (default).

  * edit - Alter an entry's note, start, or end time. Defaults to the active entry.
    usage: t edit [--id ID] [--start TIME] [--end TIME] [--append] [NOTES]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
    -s, --start <time:qs>     Change the start time to <time>
    -e, --end <time:qs>       Change the end time to <time>
    -z, --append              Append to the current note instead of replacing it
                                the delimiter between appended notes is
                                configurable (see configure)
    -m, --move <sheet>        Move to another sheet

  * format - Deprecated: alias for display.

  * in - Start the timer for the current timesheet.
    usage: t in [--at TIME] [NOTES]
    -a, --at <time:qs>        Use this time instead of now

  * kill - Delete a timesheet or an entry.
    usage: t kill [--id ID] [TIMESHEET]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry

  * list - Show the available timesheets.
    usage: t list

  * now - Show the status of the current timesheet.
    usage: t now

  * out - Stop the timer for the current timesheet.
    usage: t out [--at TIME]
    -a, --at <time:qs>        Use this time instead of now

  * running - Show all running timesheets.
    usage: t running

  * switch - Switch to a new timesheet.
    usage: t switch TIMESHEET

  * week - Shortcut for display with start date set to monday of this week.
    usage: t week [--ids] [--end DATE] [--format FMT] [SHEET | all]

  OTHER OPTIONS

  -h, --help              Display this help.
  -r, --round             Round output to 15 minute start and end times.
  -y, --yes               Noninteractive, assume yes as answer to all prompts.

  EXAMPLES

  # create the "MyTimesheet" timesheet
  $ t switch MyTimesheet

  # check in 5 minutes ago with a note
  $ t in --at '5 minutes ago' doing some stuff

  # check out
  $ t out

  # view current timesheet
  $ t display

  Submit bugs and feature requests to http://github.com/samg/timetrap/issues
    EOF

    def parse arguments
      args.parse arguments
    end

    def invoke
      args['-h'] ? puts(USAGE) : invoke_command_if_valid
    rescue => e
      warn e.message
      exit 1 unless defined? TEST_MODE
    end

    def commands
      Timetrap::CLI::USAGE.scan(/\* \w+/).map{|s| s.gsub(/\* /, '')}
    end

    def invoke_command_if_valid
      command = args.unused.shift
      set_global_options
      case (valid = commands.select{|name| name =~ %r|^#{command}|}).size
      when 0 then puts "Invalid command: #{command}"
      when 1 then send valid[0]
      else
        warn "Ambiguous command: #{command}" if command
        warn(USAGE)
      end
    end

    # currently just sets whether output should be rounded to 15 min intervals
    def set_global_options
      Timetrap::Entry.round = true if args['-r']
    end

    def archive
      ee = selected_entries
      if ask_user "Archive #{ee.count} entries? "
        ee.all.each do |e|
          next unless e.end
          e.update :sheet => "_#{e.sheet}"
        end
      else
        puts "archive aborted!"
      end
    end

    def configure
      Config.configure!
      puts "Config file is at #{Config::PATH.inspect}"
    end

    def edit
      entry = args['-i'] ? Entry[args['-i']] : Timetrap.active_entry
      warn "can't find entry" && return unless entry
      entry.update :start => args['-s'] if args['-s'] =~ /.+/
      entry.update :end => args['-e'] if args['-e'] =~ /.+/

      # update sheet
      if args['-m'] =~ /.+/
        if entry == Timetrap.active_entry
          Timetrap.current_sheet = args['-m']
        end
        entry.update :sheet => args['-m']
      end

      # update notes
      if unused_args =~ /.+/
        note = unused_args
        if args['-z']
          note = [entry.note, note].join(Config['append_notes_delimiter'])
        end
        entry.update :note => note
      end
    end

    def backend
      exec "sqlite3 #{DB_NAME}"
    end

    def in
      Timetrap.start unused_args, args['-a']
      warn "Checked into sheet #{Timetrap.current_sheet.inspect}."
    end

    def out
      if Timetrap.stop args['-a']
        warn "Checked out of sheet #{Timetrap.current_sheet.inspect}."
      else
        warn "Timetrap is not running."
      end
    end

    def kill
      if e = Entry[args['-i']]
        out = "are you sure you want to delete entry #{e.id}? "
        out << "(#{e.note}) " if e.note.to_s =~ /.+/
        if ask_user out
          e.destroy
          warn "it's dead"
        else
          warn "will not kill"
        end
      elsif (sheets = Entry.map{|e| e.sheet }.uniq).include?(sheet = unused_args)
        victims = Entry.filter(:sheet => sheet).count
        if ask_user "are you sure you want to delete #{victims} entries on sheet #{sheet.inspect}? "
          Timetrap.kill_sheet sheet
          warn "killed #{victims} entries"
        else
          warn "will not kill"
        end
      else
        victim = args['-i'] ? args['-i'].to_s.inspect : sheet.inspect
        warn "can't find #{victim} to kill", 'sheets:', *sheets
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
        warn "Invalid format #{args['-f'].inspect} specified."
        return
      end
      entries = selected_entries.order(:start).all
      if entries == []
        warn "No entries were selected to display."
      else
        puts fmt_klass.new(entries).output
      end
    end
    alias_method :format, :display

    def switch
      sheet = unused_args
      if not sheet =~ /.+/ then puts "No sheet specified"; return end
      warn "Switching to sheet " + Timetrap.switch(sheet)
    end

    def list
      sheets = ([Timetrap.current_sheet] | Entry.sheets).map do |sheet|
        sheet_atts = {:total => 0, :running => 0, :today => 0}
        entries = Timetrap::Entry.filter(:sheet => sheet)
        if entries.empty?
          sheet_atts.merge(:name => sheet)
        else
          entries.inject(sheet_atts) do |m, e|
            e_end = e.end_or_now
            m[:name] ||= sheet
            m[:total] += (e_end.to_i - e.start.to_i)
            m[:running] += (e_end.to_i - e.start.to_i) unless e.end
            m[:today] += (e_end.to_i - e.start.to_i) if same_day?(Time.now, e.start)
            m
          end
        end
      end.sort_by{|sheet| sheet[:name].downcase}
      width = sheets.sort_by{|h|h[:name].length }.last[:name].length + 4
      puts " %-#{width}s%-12s%-12s%s" % ["Timesheet", "Running", "Today", "Total Time"]
      sheets.each do |sheet|
        star = sheet[:name] == Timetrap.current_sheet ? '*' : ' '
        puts "#{star}%-#{width}s%-12s%-12s%s" % [
          sheet[:running],
          sheet[:today],
          sheet[:total]
        ].map(&method(:format_seconds)).unshift(sheet[:name])
      end
    end

    def now
      if Timetrap.running?
        out = "#{Timetrap.current_sheet}: #{format_duration(Timetrap.active_entry.start, Timetrap.active_entry.end_or_now)}".gsub(/  /, ' ')
        out << " (#{Timetrap.active_entry.note})" if Timetrap.active_entry.note =~ /.+/
        puts out
      else
        puts "#{Timetrap.current_sheet}: not running"
      end
    end

    def running
      puts "Running Timesheets:"
      puts Timetrap::Entry.filter(:end => nil).map{|e| "  #{e.sheet}: #{e.note}"}.uniq.sort
    end

    def week
      args['-s'] = Date.today.wday == 1 ? Date.today.to_s : Date.parse(Chronic.parse(%q(last monday)).to_s).to_s
      display
    end

    private

    def unused_args
      args.unused.join(' ')
    end

    def ask_user question
      return true if args['-y']
      $stderr.print question
      $stdin.gets =~ /\Aye?s?\Z/i
    end

  end
end
