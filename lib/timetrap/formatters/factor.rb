module Timetrap
  module Formatters
    class Factor
      raise <<-WARN
The factor formatter has been moved out of timetrap core in and into timetrap_formatters.
See https://github.com/samg/timetrap_formatters for more info.
      WARN
      def output; end
      def initialize(*args); end
    end
  end
end
