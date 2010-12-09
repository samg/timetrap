require 'rubygems'
require 'chronic'
require 'sequel'
require 'yaml'
require 'sequel/extensions/inflector'
require 'Getopt/Declare'
require File.join(File.dirname(__FILE__), 'timetrap', 'config')
require File.join(File.dirname(__FILE__), 'timetrap', 'helpers')
require File.join(File.dirname(__FILE__), 'timetrap', 'cli')
require File.join(File.dirname(__FILE__), 'timetrap', 'timer')
require File.join(File.dirname(__FILE__), 'timetrap', 'formatters')
module Timetrap
  DB_NAME = defined?(TEST_MODE) ? nil : Timetrap::Config['database_file']
  # connect to database.  This will create one if it doesn't exist
  DB = Sequel.sqlite DB_NAME
  CLI.args = Getopt::Declare.new(<<-EOF)
    #{CLI::USAGE}
  EOF
end
require File.join(File.dirname(__FILE__), 'timetrap', 'models')
