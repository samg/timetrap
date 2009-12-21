module Timetrap
  module Config
    extend self
    PATH = ENV['TIMETRAP_CONFIG_FILE'] || File.join(ENV['HOME'], '.timetrap.yml')

    # Application defaults.
    #
    # These are written to a config file by invoking:
    # <code>
    # t configure
    # </code>
    def defaults
      {
        # Path to the sqlite db
        'database_file' => "#{ENV['HOME']}/.timetrap.db",
        # Unit of time for rounding (-r) in seconds
        'round_in_seconds' => 900
      }
    end

    def [](key)
      overrides = File.exist?(PATH) ? YAML.load(File.read(PATH)) : {}
      defaults.merge(overrides)[key]
    rescue => e
      puts "invalid config file"
      puts e.message
      defaults[key]
    end

    def configure!
      unless File.exist?(PATH)
        File.open(PATH, 'w') do |fh|
          fh.puts(defaults.to_yaml)
        end
      end
    end
  end
end
