# Defines the table schemas. Acts as migration.
#
# Npte the executing below the classes. These create the tables
module Timetrap
  class Schema
    def self.create_table!
      DB.drop_table(self::TABLE)
      create_table
    end

    def self.create_table
      self.new.create_table
    end

    def self.try_create_table
      create_table unless DB.table_exists?(self::TABLE)
    end
  end

  class EntrySchema < Schema
    TABLE = :entries
    def create_table
      DB.create_table(TABLE) do
        primary_key :id
        column :note, String
        column :start, DateTime
        column :end, DateTime
        column :sheet, String
      end
    end
  end

  class MetaSchema < Schema
    TABLE = :meta
    def create_table
      DB.create_table(TABLE) do
        primary_key :id
        column :key, String
        column :value, String
      end
    end
  end

  ## Executes the schema, acting as a small migration
  EntrySchema.try_create_table
  MetaSchema.try_create_table
end
