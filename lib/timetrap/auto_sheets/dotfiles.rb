module Timetrap
  module AutoSheets
    class Dotfiles
      attr_accessor :current_sheet

      def initialize(current_sheet)
        self.current_sheet = current_sheet
      end

      def sheet
        dotfile = File.join(Dir.pwd, '.timetrap-sheet')
        File.read(dotfile).chomp if File.exist?(dotfile)
      end

    end
  end
end
