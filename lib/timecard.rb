require 'rubygems'
require 'chronic'
require 'sequel'
require 'Getopt/Declare'
# connect to database.  This will create one if it doesn't exist
DB_NAME = defined?(TEST_MODE) ? nil : "#{ENV['HOME']}/.timecard.db"
DB = Sequel.sqlite DB_NAME

module Timecard
  extend self

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
    Entry.filter(:sheet => sheet)
  end

  def running?
    !!active_entry
  end

  def active_entry
    Entry.find(:sheet => Timecard.current_sheet, :end => nil)
  end

  def stop time = Time.now
    while a = active_entry
      a.end = time
      a.save
    end
  end

  def start note, time = Time.now
    raise AlreadyRunning if running?
    Entry.create :sheet => Timecard.current_sheet, :note => note, :start => time
  rescue => e
    CLI.say e.message
  end

  def switch sheet
    self.current_sheet = sheet
  end

  class AlreadyRunning < StandardError
    def message
      "Timecard is already running"
    end
  end

  module CLI
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

    def invoke command, *args
      invoke_command_if_valid(command, *args)
    end

    def invoke_command_if_valid command, *args
      case (valid = COMMANDS.keys.select{|name| name =~ %r|^#{command}|}).size
      when 0 then say "Invalid command: #{command}"
      when 1 then send valid[0], *args
      else; say "Ambigous command: #{command}"; end
    end

    def alter *new_note
      Timecard.active_entry.update :note => new_note.join(' ')
    end

    def switch sheet = nil
      if not sheet then say "No sheet specified"; return end
      say "Switching to sheet " + Timecard.switch(sheet)
    end

    def list
      say "Timesheets:"
      sheets = Entry.map{|e|e.sheet} << Timecard.current_sheet
      say(*sheets.uniq.sort.map do |str|
        if str == Timecard.current_sheet
          "  * %s" % str
        else
          "  - %s" % str
        end
      end)
    end

    def in *d
      Timecard.start d.join(' ')
    end

    def out
      Timecard.stop
    end

    def display
      say DB[:entries].filter(:sheet => Timecard.current_sheet).all
    end

    def say *something
      puts *something if Timecard.invoked_as_executable?
    end
  end

  class Entry < Sequel::Model
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
    set_schema do
      primary_key :id
      column :key, :string
      column :value, :string
    end
    create_table unless table_exists?
  end
  ARGS = Getopt::Declare.new(<<-'EOF')
    -a, --at <time:s>        Use this time instead of now
  EOF
  CLI.invoke(*ARGV) if invoked_as_executable?
end
