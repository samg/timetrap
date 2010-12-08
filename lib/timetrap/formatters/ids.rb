module Timetrap
  module Formatters
    class Ids
      attr_reader :output

      def initialize entries
        @output = entries.map(&:id).join(' ')
      end
    end
  end
end
