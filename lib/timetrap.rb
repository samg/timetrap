require 'rubygems'
require 'chronic'
require 'sequel'
require 'yaml'
require 'sequel/extensions/inflector'
require 'Getopt/Declare'
require File.join(File.dirname(__FILE__), 'timetrap', 'config')
require File.join(File.dirname(__FILE__), 'timetrap', 'helpers')
require File.join(File.dirname(__FILE__), 'timetrap', 'cli')
DB_NAME = defined?(TEST_MODE) ? nil : Timetrap::Config['database_file']
# connect to database.  This will create one if it doesn't exist
DB = Sequel.sqlite DB_NAME
require File.join(File.dirname(__FILE__), 'timetrap', 'models')
Dir["#{File.dirname(__FILE__)}/timetrap/formatters/*.rb"].each do |path|
  require path
end

module Timetrap
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

  def format format_klass, entries
    format_klass.new(entries).output
  end

  class AlreadyRunning < StandardError
    def message
      "Timetrap is already running"
    end
  end

  CLI.args = Getopt::Declare.new(<<-EOF)
    #{CLI::USAGE}
  EOF
end
