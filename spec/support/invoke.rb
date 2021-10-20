def invoke(command)
  Timetrap::CLI.parse command
  Timetrap::CLI.invoke
end
