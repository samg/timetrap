require File.join(File.dirname(__FILE__), '..', 'timecard')
require 'spec'

describe Entry do
  before do
    @time = Time.now
    @entry = Entry.new
  end

  describe 'attributes' do
    it "should have a description" do
      @entry.description = "world takeover"
      @entry.description.should == "world takeover"
    end

    it "should have a start_time" do
      @entry.start_time = @time
      @entry.start_time.should == @time
    end

    it "should have a end_time" do
      @entry.end_time = @time
      @entry.end_time.should == @time
    end

    it "should have a sheet" do
      @entry.sheet= 'name'
      @entry.sheet.should == 'name'
    end
  end

  describe "parsing natural language times" do
    it "should set start time using english" do
      @entry.start_time = "yesterday 10am"
      @entry.start_time.should_not be_nil
      @entry.start_time.should == Chronic.parse("yesterday 10am")
    end

    it "should set end time using english" do
      @entry.end_time = "tomorrow 1pm"
      @entry.end_time.should_not be_nil
      @entry.end_time.should == Chronic.parse("tomorrow 1pm")
    end
  end
end
