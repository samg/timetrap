require 'rubygems'
require 'sqlite3'
require 'activerecord'

# connect to database.  This will create one if it doesn't exist
MY_DB_NAME = "~/.timecard.db"
MY_DB = SQLite3::Database.new(MY_DB_NAME)

# get active record set up
ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => MY_DB_NAME)

# create your AR class
class Entry < ActiveRecord::Base

end

# do a quick pseudo migration.  This should only get executed on the first run
if !Entry.table_exists?
  ActiveRecord::Base.connection.create_table(:entries) do |t|
    t.column :description, :string
    t.column :start_time, :timestamp
    t.column :end_time, :timestamp
    t.column :timesheet, :string
  end
end
