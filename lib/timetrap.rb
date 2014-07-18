require "rubygems"

require 'chronic'
require 'sequel'
require 'yaml'
require 'erb'
require 'sequel/extensions/inflector'
require File.join(File.dirname(__FILE__), 'timetrap', 'version')
require File.join(File.dirname(__FILE__), 'Getopt/Declare')
require File.join(File.dirname(__FILE__), 'timetrap', 'config')
require File.join(File.dirname(__FILE__), 'timetrap', 'helpers')
require File.join(File.dirname(__FILE__), 'timetrap', 'cli')
require File.join(File.dirname(__FILE__), 'timetrap', 'timer')
require File.join(File.dirname(__FILE__), 'timetrap', 'formatters')
require File.join(File.dirname(__FILE__), 'timetrap', 'auto_sheets')
require File.join(File.dirname(__FILE__), 'timetrap', 'boot')
module Timetrap
  DB_NAME = defined?(TEST_MODE) ? nil : Timetrap::Config['database_file']
  # Make the .config/timetrap dir
  Timetrap::Boot.new.run
  # connect to database.  This will create one if it doesn't exist
  DB = Sequel.sqlite DB_NAME
  CLI.args = Getopt::Declare.new(<<-EOF)
    #{CLI::USAGE}
  EOF
end
require File.join(File.dirname(__FILE__), 'timetrap', 'models')
