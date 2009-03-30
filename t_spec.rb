require 'rubygems'
require 't.rb'

describe Entry do
  before{ @entry = Entry.new }
  it "should have the right attributes" do
    @entry.update_attributes(
      :description => "world takeover",
      :start_time => Time.parse("2008-10-03 10:30 AM"),
      :end_time => Time.parse("2008-10-03 12:30 PM"),
      :sheet => 'evilllc'
    )
  end
end
