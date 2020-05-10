require "rubygems"

require 'chronic'
require 'tempfile'
require 'sequel'
require 'yaml'
require 'erb'
require 'sequel/extensions/inflector'
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'version'))
require File.expand_path(File.join(File.dirname(__FILE__), 'Getopt/Declare'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'config'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'helpers'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'cli'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'timer'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'formatters'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'auto_sheets'))
module Timetrap
  DB_NAME = defined?(TEST_MODE) ? nil : Timetrap::Config['database_file']
  # connect to database.  This will create one if it doesn't exist
  DB = Sequel.sqlite DB_NAME
  # only declare cli options when run as standalone
  if %w[dev_t t timetrap].include?(File.basename($PROGRAM_NAME)) || defined?(TEST_MODE)
    CLI.args = Getopt::Declare.new(<<-EOF)
    #{CLI::USAGE}
    EOF
  end
end
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'schema'))
require File.expand_path(File.join(File.dirname(__FILE__), 'timetrap', 'models'))
