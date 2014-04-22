module Timetrap
  class Hooks

    class << self
      def method_missing(m, *args)
        hook = hook_path(Timer.current_sheet, m)
        require hook if File.exist? hook
      end

      private
      def hook_path(command, sheet)
        path = File.join Timetrap::Config['hooks_path'], command.to_s, sheet.to_s
        path += '.rb'
      end
    end

  end
end
