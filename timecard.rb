require 'rubygems'
require 'chronic'
require 'sequel'

# connect to database.  This will create one if it doesn't exist
DB_NAME = ".timecard.db"
DB = Sequel.sqlite DB_NAME


# create your AR class
class Entry < Sequel::Model
  def start_time= time
    super Chronic.parse(time) || time
  end

  def end_time= time
    super Chronic.parse(time) || time
  end
end

module Timecard
end

if $0 == __FILE__ # invoked as executable
end

# do a quick pseudo migration.  This should only get executed on the first run
if !Entry.table_exists?
  DB.create_table(:entries) do
    primary_key :id
    column :description, :string
    column :start_time, :timestamp
    column :end_time, :timestamp
    column :sheet, :string
  end
end
