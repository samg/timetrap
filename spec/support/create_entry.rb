def create_entry(atts = {})
  Timetrap::Entry.create({
    sheet: 'default',
    start: Time.now,
    end: Time.now,
    note: 'note'
  }.merge(atts))
end
