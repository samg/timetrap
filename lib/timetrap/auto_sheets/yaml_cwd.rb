module Timetrap
  module AutoSheets
    ### auto_sheet_paths
    #
    # Specify which sheet to automatically use in which directories in with the
    # following format in timetrap.yml:
    #
    # auto_sheet_paths:
    #   Sheet name: /path/to/directory
    #   More specific sheet: /path/to/directory/that/is/nested
    #   Other sheet:
    #     - /path/to/first/directory
    #     - /path/to/second/directory
    #
    # **Note** Timetrap will always use the sheet specified in the config file
    # if you are in that directory (or in its tree). To use a different sheet,
    # you must be in a different directory.
    #
    class YamlCwd
      def sheet
        auto_sheet = nil
        cwd = "#{Dir.getwd}/"
        most_specific = 0
        Array(Timetrap::Config['auto_sheet_paths']).each do |sheet, dirs|
          Array(dirs).each do |dir|
            if cwd.start_with?(dir) && dir.length > most_specific
              most_specific = dir.length
              auto_sheet = sheet
            end
          end
        end
        auto_sheet
      end
    end
  end
end
