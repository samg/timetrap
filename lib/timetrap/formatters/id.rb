module Timetrap
  module Formatters
    class Id
      attr_reader :output

      def initialize entries
        @output = entries.map(&:id).join(' ')
      end
    end
  end
end
