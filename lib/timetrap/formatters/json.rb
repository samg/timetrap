begin
  require 'json'
rescue LoadError
  raise <<-ERR
The json gem must be installed for json output.
To install it:
$ [sudo] gem install json -v"~>1.4.6"
  ERR
end

module Timetrap
  module Formatters
    class Json
      attr_accessor :output

      def initialize entries
        @output = entries.map do |e|
          next unless e.end

          e.values.inject({}) do |h, (k,v)|
            h[k] = v
            h[k] = e.public_send(k) if %i[end start].include?(k)
            h
          end
        end.compact.to_json
      end
    end
  end
end
