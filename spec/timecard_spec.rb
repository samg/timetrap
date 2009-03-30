require File.join(File.dirname(__FILE__), '..', 'timecard')
require 'spec'

describe Timecard::CLI do
  it "should call a valid command" do
    Timecard::CLI.should_receive(:alter).with('arg_1', 'arg_2')
    Timecard::CLI.invoke 'alter', 'arg_1', 'arg_2'
  end

  it "should call a valid command by an abbreviation" do
    Timecard::CLI.should_receive(:alter).with('arg_1', 'arg_2')
    Timecard::CLI.invoke 'a', 'arg_1', 'arg_2'
  end

  it "should not call an invalid command" do
    Timecard::CLI.should_not_receive(:exec).with('arg_1', 'arg_2')
    Timecard::CLI.invoke 'exec', 'arg_1', 'arg_2'
  end
end

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
