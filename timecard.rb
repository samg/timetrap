require 'rubygems'
require 'chronic'
require 'sequel'
# connect to database.  This will create one if it doesn't exist
DB_NAME = "#{ENV['HOME']}/.timecard.db"
DB = Sequel.sqlite DB_NAME
require 'timecard/entry'
require 'timecard/cli'

module Timecard
  private
  def self.invoked_as_executable?
    $0 == __FILE__
  end
  CLI.invoke *ARGV if invoked_as_executable?
end


