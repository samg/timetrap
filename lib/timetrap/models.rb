module Timetrap
  class Entry < Sequel::Model
    plugin :schema

    class << self
    # a class level instance variable that controls whether or not all entries
    # should respond to #start and #end with times rounded to 15 minute
    # increments.
      attr_accessor :round
    end

    def round?
      !!self.class.round
    end

    def start= time
      self[:start]= Timer.process_time(time)
    end

    def end= time
      self[:end]= Timer.process_time(time)
    end

    def start
      round? ? rounded_start : self[:start]
    end

    def end
      round? ? rounded_end : self[:end]
    end

    def end_or_now
      self.end || (round? ? round(Time.now) : Time.now)
    end

    def rounded_start
      round(self[:start])
    end

    def rounded_end
      round(self[:end])
    end

    def round time
      return nil unless time
      Time.at(
        if (r = time.to_i % Timetrap::Config['round_in_seconds']) < 450
          time.to_i - r
        else
          time.to_i + (Timetrap::Config['round_in_seconds'] - r)
        end
      )
    end

    def sheet
      Sheet[:id => self[:sheet_id]]
    end

    def sheet= sheet
      self[:sheet_id] = sheet.id
      self.save
    end

    def self.sheets
      Sheet.all.sort { |a, b| a.name <=> b.name }
    end
    
    def bill
      return nil if sheet.rate.nil?
      
      e_end = end_or_now
      bill = currencify(( e_end - start ) / 3600.0 * sheet.rate )
    end
    
    def currencify number, options = {}
      # :currency_before => false puts the currency symbol after the number
      # default format: $12,345,678.90
      options = {:currency_symbol => "$", :delimiter => ",", :decimal_symbol => ".", :currency_before => true}.merge(options)
      
      # split integer and fractional parts
      int, frac = ("%.2f" % number).split(".")
      # insert the delimiters
      int.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")
      
      if options[:currency_before]
        options[:currency_symbol] + int + options[:decimal_symbol] + frac
      else
        int + options[:decimal_symbol] + frac + options[:currency_symbol]
      end
    end

    private
    # do a quick pseudo migration.  This should only get executed on the first run
    set_schema do
      primary_key :id
      column :note, :string
      column :start, :timestamp
      column :end, :timestamp
      column :sheet_id, :int
    end
    create_table unless table_exists?
  end

  class Sheet < Sequel::Model
    plugin :schema

    set_schema do
      primary_key :id
      column :name, :string
      column :rate, :integer
    end

    unless table_exists?
      create_table
      Sheet.create :name => 'default'
    end
  end

  class Meta < Sequel::Model(:meta)
    plugin :schema

    set_schema do
      primary_key :id
      column :key, :string
      column :value, :string
    end
    create_table unless table_exists?
  end
end
