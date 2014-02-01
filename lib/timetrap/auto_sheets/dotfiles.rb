module Timetrap
  module AutoSheets
    class Dotfiles
      def sheet
        dotfile = File.join(Dir.pwd, '.timetrap-sheet')
        File.read(dotfile).chomp if File.exist?(dotfile)
      end
    end
  end
end
