module Timetrap
  class Hooks

    class << self

      __display = instance_method(:display)
      define_method(:display){ |*args| method_missing(:display, args) }

      def method_missing(m, *args, &block)
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
