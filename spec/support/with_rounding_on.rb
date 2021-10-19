def with_rounding_on
  old_round = Timetrap::Entry.round
  begin
    Timetrap::Entry.round = true
    block_return_value = yield
  ensure
    Timetrap::Entry.round = old_round
  end
end
