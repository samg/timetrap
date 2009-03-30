
module Timecard
  module CLI
    COMMANDS = {
      "alter" => "alter the description of the active period",
      "backend" => "open an the backend's interactive shell",
      "display" => "display the current timesheet",
      "format" => "export a sheet to csv format",
      "in" => "start the timer for the current timesheet",
      "kill" => "delete a timesheet",
      "list" => "show the available timesheets",
      "now" => "show the status of the current timesheet",
      "out" => "stop the timer for the current timesheet",
      "running" => "show all running timesheets",
      "switch" => "switch to a new timesheet"
    }

    def self.invoke command, *args
      invoke_command_if_valid command, *args
    end

    private
    def self.invoke_command_if_valid command, *args
      case (valid = COMMANDS.keys.select{|name| name =~ %r|^#{command}|}).size
      when 0 then say "Invalid command: #{command}"
      when 1 then send valid[0], *args
      else; say "Ambigous command: #{command}"; end
    end

    def self.say something
      puts something if Timecard.invoked_as_executable?
    end
  end
end


