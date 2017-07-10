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
        'round_in_seconds' => 900,
        # delimiter used when appending notes with `t edit --append`
        'append_notes_delimiter' => ' ',
        # an array of directories to search for user defined fomatter classes
        'formatter_search_paths' => [
          "#{ENV['HOME']}/.timetrap/formatters"
        ],
        # formatter to use when display is invoked without a --format option
        'default_formatter' => 'text',
        # the auto_sheet to use
        'auto_sheet' => 'dotfiles',
        # an array of directories to search for user defined auto_sheet classes
        'auto_sheet_search_paths' => [
          "#{ENV['HOME']}/.timetrap/auto_sheets"
        ],
        # the default command to when you run `t`.  default to printing usage.
        'default_command' => nil,
        # only allow one running entry at a time.
        # automatically check out of any running tasks when checking in.
        'auto_checkout' => false,
        # interactively prompt for a note if one isn't passed when checking in.
        'require_note' => false,
        # command to launch external editor (false if no external editor used)
        'note_editor' => false,
        # set day of the week when determining start of the week.
        'week_start' => "Monday",
      }
    end

    def [](key)
      overrides = File.exist?(PATH) ? YAML.load(erb_render(File.read(PATH))) : {}
      defaults.merge(overrides)[key]
    rescue => e
      warn "invalid config file"
      warn e.message
      defaults[key]
    end

    def erb_render(content)
      ERB.new(content).result
    end

    def configure!
      configs = if File.exist?(PATH)
        defaults.merge(YAML.load_file(PATH))
      else
        defaults
      end
      File.open(PATH, 'w') do |fh|
        fh.puts(configs.to_yaml)
      end
    end
  end
end
