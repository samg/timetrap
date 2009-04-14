#!/usr/bin/env ruby
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

    COMMANDS = {
      "alter" => "alter the description of the active period",
      "backend" => "open an the backend's interactive shell",
      "display" => "display the current timesheet",
      "format" => "export a sheet to csv format",
      "in" => "start the timer for the current timesheet",
      "kill" => "delete a timesheet",
      "list" => "show the available timesheets",
      "now" => "show the status of the current timesheet",
      "out" => "stop the timer for the current timesheet",
      "running" => "show all running timesheets",
      "switch" => "switch to a new timesheet"
    }

    def parse arguments
      args.parse arguments
    end

    def invoke
      invoke_command_if_valid
    end

    def invoke_command_if_valid
      command = args.unused.shift
      case (valid = COMMANDS.keys.select{|name| name =~ %r|^#{command}|}).size
      when 0 then say "Invalid command: #{command}"
      when 1 then send valid[0]
      else; say "Ambigous command: #{command}"; end
    end

    def alter
      Timetrap.active_entry.update :note => args.unused.join(' ')
    end

    def backend
      exec "sqlite3 #{DB_NAME}"
    end

    def in
      Timetrap.start args.unused.join(' '), args['--at']
    end

    def out
      Timetrap.stop args['--at']
    end

    def display
      sheet = sheet_name_from_string(args.unused.join(' '))
      sheet = (sheet =~ /.+/ ? sheet : Timetrap.current_sheet)
      say "Timesheet: #{sheet}"
      say "           Day                Start      End        Duration   Notes"
      last_start = nil
      from_current_day = []
      (ee = Timetrap.entries(sheet)).each_with_index do |e, i|


        from_current_day << e
        e_end = e.end || Time.now
        say "%27s%11s -%9s%10s    %s" % [
          format_date_if_new(e.start, last_start),
          format_time(e.start),
          format_time(e.end),
          format_duration(e.start, e_end),
          e.note
        ]

        nxt = Timetrap.entries(sheet).map[i+1]
        if nxt == nil or !same_day?(e.start, nxt.start)
          say "%59s" % format_total(from_current_day)
          from_current_day = []
        else
        end
        last_start = e.start
      end
      say <<-OUT
           ---------------------------------------------------------
      OUT
      say "           Total%43s" % format_total(ee)
    end

    def switch
      sheet = args.unused.join(' ')
      if not sheet then say "No sheet specified"; return end
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

  def invoked_as_executable?
    $0 == __FILE__
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

  class AlreadyRunning < StandardError
    def message
      "Timetrap is already running"
    end
  end


  class Entry < Sequel::Model
    Sequel::Model.plugin(:schema)
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
    Sequel::Model.plugin(:schema)
    set_schema do
      primary_key :id
      column :key, :string
      column :value, :string
    end
    create_table unless table_exists?
  end
  CLI.args = Getopt::Declare.new(<<-'EOF')
    -a, --at <time:qs>        Use this time instead of now
  EOF
  CLI.invoke if invoked_as_executable?
end
