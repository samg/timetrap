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
    -g, --grep <regexp>       Include entries where the note matches this regexp.

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
      formatter_search_paths: an array of directories to search for user
                              defined fomatter classes
      default_formatter:      The format to use when display is invoked without a
                              `--format` option
      default_command:        The default command to run when calling t.
      auto_checkout:          Automatically check out of running entries when
                              you check in or out
      require_note:           Prompt for a note if one isn't provided when
                              checking in
      note_editor:            Command to launch notes editor or false if no editor use.
                              If you use a non terminal based editor (e.g. sublime, atom)
                              please read the notes in the README.
      week_start:             The day of the week to use as the start of the
                              week for t week.

  * display - Display the current timesheet or a specific. Pass `all' as SHEET
      to display all unarchived sheets or `full' to display archived and
      unarchived sheets.
    usage: t display [--ids] [--start DATE] [--end DATE] [--format FMT] [SHEET | all | full]
    -v, --ids                 Print database ids (for use with edit)
    -s, --start <date:qs>     Include entries that start on this date or later
    -e, --end <date:qs>       Include entries that start on this date or earlier
    -f, --format <format>     The output format.  Valid built-in formats are
                              ical, csv, json, ids, factor, and text (default).
                              Documentation on defining custom formats can be
                              found in the README included in this
                              distribution.
    -g, --grep <regexp>       Include entries where the note matches this regexp.

  * edit - Alter an entry's note, start, or end time. Defaults to the active
    entry. Defaults to the last entry to be checked out of if no entry is active.
    usage: t edit [--id ID] [--start TIME] [--end TIME] [--append] [NOTES]
    -i, --id <id:i>           Alter entry with id <id> instead of the running entry
    -s, --start <time:qs>     Change the start time to <time>
    -e, --end <time:qs>       Change the end time to <time>
    -z, --append              Append to the current note instead of replacing it
                                the delimiter between appended notes is
                                configurable (see configure)
    -c, --clear               Allow an empty note, can be used to clear existing notes
    -m, --move <sheet>        Move to another sheet

  * in - Start the timer for the current timesheet.
    usage: t in [--at TIME] [NOTES]
    -a, --at <time:qs>        Use this time instead of now

  * kill - Delete a timesheet or an entry.
    usage: t kill [--id ID] [TIMESHEET]
    -i, --id <id:i>           Delete entry with id <id> instead of timesheet

  * list - Show the available timesheets.
    usage: t list

  * now - Show all running entries.
    usage: t now

  * out - Stop the timer for a timesheet.
    usage: t out [--at TIME] [TIMESHEET]
    -a, --at <time:qs>        Use this time instead of now

  * resume - Start the timer for the current time sheet for an entry. Defaults
      to the active entry.
    usage: t resume [--id ID] [--at TIME]
    -i, --id <id:i>           Resume entry with id <id> instead of the last entry
    -a, --at <time:qs>        Use this time instead of now

  * sheet - Switch to a timesheet creating it if necessary. When no sheet is
      specified list all sheets. The special sheetname '-' will switch to the
      last active sheet.
    usage: t sheet [TIMESHEET]

  * today - Shortcut for display with start date as the current day
    usage: t today [--ids] [--format FMT] [SHEET | all]

  * yesterday - Shortcut for display with start and end dates as the day before the current day
    usage: t yesterday [--ids] [--format FMT] [SHEET | all]

  * week - Shortcut for display with start date set to a day of this week.
    The default start of the week is Monday.
.
    usage: t week [--ids] [--end DATE] [--format FMT] [SHEET | all]

  * month - Shortcut for display with start date set to the beginning of either
      this month or a specified month.
    usage: t month [--ids] [--start MONTH] [--format FMT] [SHEET | all]

  OTHER OPTIONS

  -h, --help              Display this help.
  -r, --round             Round output to 15 minute start and end times.
  -y, --yes               Noninteractive, assume yes as answer to all prompts.
  --debug                 Display stack traces for errors.

  EXAMPLES

  # create the "MyTimesheet" timesheet
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
      if args.unused.empty? && Timetrap::Config['default_command']
        self.args = Getopt::Declare.new(USAGE.dup, Timetrap::Config['default_command'])
      end
      command = args.unused.shift
      set_global_options
      case (valid = commands.select{|name| name =~ %r|^#{command}|}).size
      when 1 then send valid[0]
      else
        handle_invalid_command(command)
      end
    end

    def valid_command(command)
       return commands.include?(command)
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
        ee.each do |e|
          next unless e.end
          e.update :sheet => "_#{e.sheet}"
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
      entry = case
              when args['-i']
                warn "Editing entry with id #{args['-i'].inspect}"
                Entry[args['-i']]
              when Timer.active_entry
                warn "Editing running entry"
                Timer.active_entry
              when Timer.last_checkout
                warn  "Editing last entry you checked out of"
                Timer.last_checkout
              end

      unless entry
        warn "Can't find entry"
        return
      end
      warn ""

      entry.update :start => args['-s'] if args['-s'] =~ /.+/
      entry.update :end => args['-e'] if args['-e'] =~ /.+/

      # update sheet
      if args['-m'] =~ /.+/
        if entry == Timer.active_entry
          Timer.current_sheet = args['-m']
        end
        entry.update :sheet => args['-m']
      end

      if Config['note_editor']
        if args['-c']
          entry.update :note => ''
        elsif args['-z']
          note = [entry.note, get_note_from_external_editor].join(Config['append_notes_delimiter'])
          entry.update :note => note
        elsif editing_a_note?
          entry.update :note => get_note_from_external_editor(entry.note)
        end
      else
        if args['-c']
          entry.update :note => ''
        elsif unused_args =~ /.+/
          note = unused_args
          if args['-z']
            note = [entry.note, note].join(Config['append_notes_delimiter'])
          end
          entry.update :note => note
        end
      end


      puts format_entries(entry)
    end

    def backend
      exec "sqlite3 #{DB_NAME}"
    end

    def in
      if Config['auto_checkout']
        Timer.stop_all(args['-a']).each do |checked_out_of|
          warn "Checked out of sheet #{checked_out_of.sheet.inspect}."
        end
      end

      note = unused_args
      if Config['require_note'] && !Timer.running? && unused_args.empty?
        if Config['note_editor']
          note = get_note_from_external_editor
        else
          $stderr.print("Please enter a note for this entry:\n> ")
          note = $stdin.gets.strip
        end
      end

      Timer.start note, args['-a']
      warn "Checked into sheet #{Timer.current_sheet.inspect}."
    end

    def resume
      entry = case
              when args['-i']
                entry = Entry[args['-i']]
                unless entry
                  warn "No such entry (id #{args['-i'].inspect})!"
                  return
                end
                warn "Resuming entry with id #{args['-i'].inspect} (#{entry.note})"
                entry
              else
                last_entry = Timer.entries(Timer.current_sheet).order(:id).last
                last_entry ||= Timer.entries("_#{Timer.current_sheet}").order(:id).last
                warn "No entry yet on this sheet yet. Started a new entry." unless last_entry
                note = (last_entry ? last_entry.note : nil)
                warn "Resuming #{note.inspect} from entry ##{last_entry.id}" if note
                last_entry
              end

      unless entry
        warn "Can't find entry"
        return
      end

      self.unused_args = entry.note || unused_args

      self.in
    end

    def out
      if Config['auto_checkout']
        stopped = Timer.stop_all(args['-a']).each do |checked_out_of|
          note = Timer.last_checkout.note
          entry = note_blank?(note) ? Timer.last_checkout.id : note.inspect
          warn "Checked out of entry #{entry} in sheet #{checked_out_of.sheet.inspect}."
        end
        if stopped.empty?
          warn "No running entries to stop."
        end
      else
        sheet = sheet_name_from_string(unused_args)
        if Timer.stop sheet, args['-a']
          note = Timer.last_checkout.note
          entry = note_blank?(note) ? Timer.last_checkout.id : note.inspect
          warn "Checked out of entry #{entry} in sheet #{sheet.inspect}."
        else
          warn "No running entry on sheet #{sheet.inspect}."
        end
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
          Entry.filter(:sheet => sheet).destroy
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
      entries = selected_entries
      if entries == []
        warn "No entries were selected to display."
      else
        puts format_entries(entries)
      end
    end

    def sheet
      sheet = unused_args
      case sheet
      when nil, ''
        list
        return
      when '-'
        if Timer.last_sheet
          sheet = Timer.last_sheet
        else
          warn 'LAST_SHEET is not set'
          return
        end
      end

      Timer.current_sheet = sheet
      if Timer.last_sheet == sheet
        warn "Already on sheet #{sheet.inspect}"
      elsif Entry.sheets.include?(sheet)
        warn "Switching to sheet #{sheet.inspect}"
      else
        warn "Switching to sheet #{sheet.inspect} (new sheet)"
      end
    end

    def list
      sheets = ([Timer.current_sheet] | Entry.sheets).map do |sheet|
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
      width = 10 if width < 10
      puts " %-#{width}s%-12s%-12s%s" % ["Timesheet", "Running", "Today", "Total Time"]
      sheets.each do |sheet|
        star = sheet[:name] == Timer.current_sheet ? '*' : sheet[:name] == Timer.last_sheet ? '-' : ' '
        puts "#{star}%-#{width}s%-12s%-12s%s" % [
          sheet[:running],
          sheet[:today],
          sheet[:total]
        ].map(&method(:format_seconds)).unshift(sheet[:name])
      end
    end

    def now
      if !Timer.running?
        warn "*#{Timer.current_sheet}: not running"
      end
      Timer.running_entries.each do |entry|
        current = entry.sheet == Timer.current_sheet
        out = current ? '*' : ' '
        out << "#{entry.sheet}: #{format_duration(entry.duration)}".gsub(/  /, ' ')
        out << " (#{entry.note})" if entry.note =~ /.+/
        puts out
      end
    end

    def today
        args['-s'] = Date.today.to_s
        display
    end

    def yesterday
      yesterday = (Date.today - 1).to_s
      args['-s'] = yesterday
      args['-e'] = yesterday
      display
    end

    def week
      d = Chronic.parse( args['-s'] || Date.today )

      today = Date.new( d.year, d.month, d.day )
      end_of_week = today + 6
      last_week_start = Date.parse(Chronic.parse('last '.concat(Config['week_start']).to_s, :now => today).to_s)
      args['-s'] = today.wday == Date.parse(Config['week_start']).wday ? today.to_s : last_week_start.to_s
      args['-e'] = end_of_week.to_s
      display
    end

    def month
      d = Chronic.parse( args['-s'] || Date.today )

      beginning_of_month = Date.new( d.year, d.month )
      end_of_month = if d.month == 12 # handle edgecase
        Date.new( d.year + 1, 1) - 1
      else
        Date.new( d.year, d.month+1 ) - 1
      end
      args['-s'] = beginning_of_month.to_s
      args['-e'] = end_of_month.to_s
      display
    end

    private

    def note_blank?(note)
      note.inspect.to_s.gsub('"', '').strip.size.zero?
    end

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

    def get_note_from_external_editor(contents = "")
      file = Tempfile.new('get_note')
      unless contents.empty?
        file.open
        file.write(contents)
        file.close
      end

      system("#{Config['note_editor']} #{file.path}")
      file.open.read
    ensure
     file.close
     file.unlink
    end

    def editing_a_note?
      return true if args.size == 0

      args.each do |(k,_v)|
        return false unless ["--id", "-i"].include?(k)
      end
      true
    end

    extend Helpers::AutoLoad
    def format_entries(entries)
      load_formatter(args['-f'] || Config['default_formatter']).new(Array(entries)).output
    end

  end
end
