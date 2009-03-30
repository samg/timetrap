class Entry < Sequel::Model
  def start_time= time
    super Chronic.parse(time) || time
  end

  def end_time= time
    super Chronic.parse(time) || time
  end

  # do a quick pseudo migration.  This should only get executed on the first run
  if !table_exists?
    DB.create_table(:entries) do
      primary_key :id
      column :description, :string
      column :start_time, :timestamp
      column :end_time, :timestamp
      column :sheet, :string
    end
  end
end
