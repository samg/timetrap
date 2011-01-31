module Timetrap
  module CLI
    extend Helpers
    attr_accessor :args
    extend self

    USAGE = <<EOF

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

  * configure - Write out a YAML config file. Print path to config file.  The
      file may contain ERB.
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
    -f, --format <format>     The output format.  Valid built-in formats are
                              ical, csv, json, ids, and text (default).
                              Documentation on defining custom formats can be
                              found in the README included in this
                              distribution.

  * edit - Alter an entry's note, start, or end time. Defaults to the active entry.
    usage: t edit [--id ID] [--start TIME] [--end TIME] [--append] [NOTES]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
    -s, --start <time:qs>     Change the start time to <time>
    -e, --end <time:qs>       Change the end time to <time>
    -z, --append              Append to the current note instead of replacing it
                                the delimiter between appended notes is
                                configurable (see configure)
    -m, --move <sheet>        Move to another sheet

  * in - Start the timer for the current timesheet.
    usage: t in [--at TIME] [NOTES]
    -a, --at <time:qs>        Use this time instead of now

  * kill - Delete a timesheet or an entry.
    usage: t kill [--id ID] [TIMESHEET]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry

  * list - Show the available timesheets.
    usage: t list

  * now - Show all running entries.
    usage: t now

  * out - Stop the timer for the a timesheet.
    usage: t out [--at TIME] [TIMESHEET]
    -a, --at <time:qs>        Use this time instead of now

  * resume - Start the timer for the current time sheet with the same note as
      the last entry on the sheet. If there is no entry it takes the passed note.
    usage: t resume [--at TIME] [NOTES]
    -a, --at <time:qs>        Use this time instead of now

  * sheet - Switch to a timesheet creating it if necessary. When no sheet is
      specified list all sheets.
    usage: t sheet [TIMESHEET]

  * week - Shortcut for display with start date set to monday of this week.
    usage: t week [--ids] [--end DATE] [--format FMT] [SHEET | all]

  OTHER OPTIONS

  -h, --help              Display this help.
  -r, --round             Round output to 15 minute start and end times.
  -y, --yes               Noninteractive, assume yes as answer to all prompts.
  --debug                 Display stack traces for errors.

  EXAMPLES

  # create the \"MyTimesheet\" timesheet
  $ t sheet MyTimesheet

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
    rescue StandardError, LoadError => e
      raise e if args['--debug']
      warn e.message
      exit 1 unless defined? TEST_MODE
    end

    def commands
      Timetrap::CLI::USAGE.scan(/\* \w+/).map{|s| s.gsub(/\* /, '')}
    end

    def deprecated_commands
      {
        'switch' => 'sheet',
        'running' => 'now',
        'format' => 'display'
      }
    end

    def invoke_command_if_valid
      command = args.unused.shift
      set_global_options
      case (valid = commands.select{|name| name =~ %r|^#{command}|}).size
      when 1 then send valid[0]
      else
        handle_invalid_command(command)
      end
    end

    def handle_invalid_command(command)
      if !command
        puts USAGE
      elsif mapping = deprecated_commands.detect{|(k,v)| k =~ %r|^#{command}|}
        deprecated, current = *mapping
        warn "The #{deprecated.inspect} command is deprecated in favor of #{current.inspect}. Sorry for the inconvenience."
        send current
      else
        warn "Invalid command: #{command.inspect}"
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
          e.sheet.update :name => "_#{e.sheet.name}"
        end
      else
        warn "archive aborted!"
      end
    end

    def configure
      Config.configure!
      puts "Config file is at #{Config::PATH.inspect}"
    end

    def edit
      entry = args['-i'] ? Entry[args['-i']] : Timer.active_entry
      unless entry
        warn "can't find entry"
        return
      else
        warn "editing entry ##{entry.id.inspect}"
      end
      entry.update :start => args['-s'] if args['-s'] =~ /.+/
      entry.update :end => args['-e'] if args['-e'] =~ /.+/

      # update sheet
      if args['-m'] =~ /.+/
        if entry == Timer.active_entry
          Timer.current_sheet = Sheet[:name => args['-m']]
        end
        entry.sheet = Sheet[:name => args['-m']]
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
      Timer.start unused_args, args['-a']
      warn "Checked into sheet #{Timer.current_sheet.name.inspect}."
    end

    def resume
      last_entry = Timer.entries(Timer.current_sheet).last
      warn "No entry yet on this sheet yet. Started a new entry." unless last_entry
      note = (last_entry ? last_entry.note : nil)
      warn "Resuming #{note.inspect} from entry ##{last_entry.id}" if note

      self.unused_args = note || unused_args

      self.in
    end

    def out
      sheet = sheet_from_string(unused_args)
      if Timer.stop sheet, args['-a']
        warn "Checked out of sheet #{sheet.name.inspect}."
      else
        warn "No running entry on sheet #{sheet.name.inspect}."
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
      elsif (sheets = Entry.map{|e| e.sheet.name }.uniq).include?(sheet = unused_args)
        victims = Entry.filter(:sheet_id => Sheet[:name => sheet].id).count
        if ask_user "are you sure you want to delete #{victims} entries on sheet #{sheet.inspect}? "
          Entry.filter(:sheet_id => Sheet[:name => sheet].id).destroy
          warn "killed #{victims} entries"
        else
          warn "will not kill"
        end
      else
        victim = args['-i'] ? args['-i'].to_s.inspect : sheet.inspect
        warn ["can't find #{victim} to kill", 'sheets:', *sheets].join("\n")
      end
    end

    def display
      entries = selected_entries.order(:start).all
      if entries == []
        warn "No entries were selected to display."
      else
        puts load_formatter(args['-f'] || Config['default_formatter']).new(entries).output
      end
    end

    def sheet
      unless unused_args =~ /.+/
        list
      else
        sheet = Sheet.find_or_create :name => unused_args
        Timer.current_sheet = sheet
        warn "Switching to sheet #{sheet.name.inspect}"
      end
    end

    def list
      sheets = ([Timer.current_sheet] | Entry.sheets).map do |sheet|
        sheet_atts = {:total => 0, :running => 0, :today => 0}
        entries = Timetrap::Entry.filter(:sheet_id => sheet.id)
        if entries.empty?
          sheet_atts.merge(:name => sheet.name)
        else
          entries.inject(sheet_atts) do |m, e|
            e_end = e.end_or_now
            m[:name] ||= sheet.name
            m[:total] += (e_end.to_i - e.start.to_i)
            m[:running] += (e_end.to_i - e.start.to_i) unless e.end
            m[:today] += (e_end.to_i - e.start.to_i) if same_day?(Time.now, e.start)
            m
          end
        end
      end.sort_by{|esheet| esheet[:name].downcase}
      width = sheets.sort_by{|h|h[:name].length }.last[:name].length + 4
      puts " %-#{width}s%-12s%-12s%s" % ["Timesheet", "Running", "Today", "Total Time"]
      sheets.each do |sheet|
        star = sheet[:name] == Timer.current_sheet.name ? '*' : ' '
        puts "#{star}%-#{width}s%-12s%-12s%s" % [
          sheet[:running],
          sheet[:today],
          sheet[:total]
        ].map(&method(:format_seconds)).unshift(sheet[:name])
      end
    end

    def now
      if !Timer.running?
        puts "*#{Timer.current_sheet.name}: not running"
      end
      Timer.running_entries.each do |entry|
        current = entry[:sheet_id] == Timer.current_sheet.id
        out = current ? '*' : ' '
        out << "#{entry.sheet.name}: #{format_duration(entry.start, entry.end_or_now)}".gsub(/  /, ' ')
        out << " (#{entry.note})" if entry.note =~ /.+/
        puts out
      end
    end

    def week
      args['-s'] = Date.today.wday == 1 ? Date.today.to_s : Date.parse(Chronic.parse(%q(last monday)).to_s).to_s
      display
    end

    private

    def unused_args
      args.unused.join(' ')
    end

    def unused_args=(str)
      args.unused = str.split
    end

    def ask_user question
      return true if args['-y']
      $stderr.print question
      $stdin.gets =~ /\Aye?s?\Z/i
    end

  end
end
