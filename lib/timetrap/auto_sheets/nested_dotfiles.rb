module Timetrap
  module AutoSheets
    #
    # Check the current dir and all parent dirs for .timetrap-sheet
    #
    class NestedDotfiles
      def check_sheet(dir)
        dotfile = File.join(dir, '.timetrap-sheet')
        File.read(dotfile).chomp if File.exist?(dotfile)
      end

      def sheet
        dir = Dir.pwd
        while true do
            sheet = check_sheet dir
            break if nil != sheet
            new_dir = File.expand_path("..", dir)
            break if new_dir == dir
            dir = new_dir
        end
        return sheet
      end
    end
  end
end
