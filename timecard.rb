require 'rubygems'
require 'chronic'
require 'sequel'
# connect to database.  This will create one if it doesn't exist
DB_NAME = "#{ENV['HOME']}/.timecard.db"
DB = Sequel.sqlite DB_NAME
require 'timecard/models'
require 'timecard/cli'

module Timecard
  def self.current_sheet= sheet
    m = Meta.find_or_create(:key => 'current_sheet')
    m.value = sheet
    m.save
  end

  def self.current_sheet
    Meta.find(:key => 'current_sheet').value
  end

  private
  def self.invoked_as_executable?
    $0 == __FILE__
  end
  CLI.invoke *ARGV if invoked_as_executable?
end


