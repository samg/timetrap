def local_time(str)
  Timetrap::Timer.process_time(str)
end

def local_time_cli(str)
  local_time(str).strftime('%Y-%m-%d %H:%M:%S')
end
