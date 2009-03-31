TEST_MODE = true
require File.join(File.dirname(__FILE__), '..', 'lib', 'timecard')
require 'spec'

describe Timecard do
  before :each do
    Timecard::Entry.create_table!
    Timecard::Meta.create_table!
  end

  describe 'CLI' do
    it "should call a valid command" do
      Timecard.should_receive(:alter).with('arg_1', 'arg_2')
      Timecard.invoke 'alter', 'arg_1', 'arg_2'
    end

    it "should call a valid command by an abbreviation" do
      Timecard.should_receive(:alter).with('arg_1', 'arg_2')
      Timecard.invoke 'a', 'arg_1', 'arg_2'
    end

    it "should not call an invalid command" do
      Timecard.should_not_receive(:exec).with('arg_1', 'arg_2')
      Timecard.invoke 'exec', 'arg_1', 'arg_2'
    end
  end

  describe "entries" do
    it "should give the entires for a sheet" do
      e = create_entry :sheet => 'sheet'
      Timecard.entries('sheet').all.should include(e)
    end

    def create_entry atts = {}
      Timecard::Entry.create({
        :sheet => 's1',
        :start => Time.now,
        :end => Time.now,
        :note => 'note'}.merge(atts))
    end
  end

  describe "start" do
    it "should start an new entry" do
      @time = Time.now
      Timecard.current_sheet = 'sheet1'
      lambda do
        Timecard.start 'some work', @time
      end.should change(Timecard::Entry, :count).by(1)
      Timecard::Entry.order(:id).last.sheet.should == 'sheet1'
      Timecard::Entry.order(:id).last.note.should == 'some work'
      Timecard::Entry.order(:id).last.start.to_i.should == @time.to_i
      Timecard::Entry.order(:id).last.end.should be_nil
    end

    it "should be running if it is started" do
      Timecard.should_not be_running
      Timecard.start 'some work', @time
      Timecard.should be_running
    end

    it "should raise and error if it is already running" do
      lambda do
        Timecard.start 'some work', @time
        Timecard.start 'some work', @time
      end.should change(Timecard::Entry, :count).by(1)
    end
  end

  describe "stop" do
    it "should stop a new entry" do
      @time = Time.now
      Timecard.start 'some work', @time
      entry = Timecard.active_entry
      entry.end.should be_nil
      Timecard.stop @time
      entry.refresh.end.to_i.should == @time.to_i
    end

    it "should not be running if it is stopped" do
      Timecard.should_not be_running
      Timecard.start 'some work', @time
      Timecard.stop
      Timecard.should_not be_running
    end

    it "should not stop it twice" do
      Timecard.start 'some work'
      e = Timecard.active_entry
      Timecard.stop
      time = e.refresh.end
      Timecard.stop
      time.to_i.should == e.refresh.end.to_i
    end

  end

  describe 'switch' do
    it "should switch to a new sheet" do
      Timecard.invoke 's', 'sheet1'
      Timecard.current_sheet.should == 'sheet1'
      Timecard.invoke 's', 'sheet2'
      Timecard.current_sheet.should == 'sheet2'
    end
  end
end

describe Timecard::Entry do
  before do
    @time = Time.now
    @entry = Timecard::Entry.new
  end

  describe 'attributes' do
    it "should have a note" do
      @entry.note = "world takeover"
      @entry.note.should == "world takeover"
    end

    it "should have a start" do
      @entry.start = @time
      @entry.start.should == @time
    end

    it "should have a end" do
      @entry.end = @time
      @entry.end.should == @time
    end

    it "should have a sheet" do
      @entry.sheet= 'name'
      @entry.sheet.should == 'name'
    end
  end

  describe "parsing natural language times" do
    it "should set start time using english" do
      @entry.start = "yesterday 10am"
      @entry.start.should_not be_nil
      @entry.start.should == Chronic.parse("yesterday 10am")
    end

    it "should set end time using english" do
      @entry.end = "tomorrow 1pm"
      @entry.end.should_not be_nil
      @entry.end.should == Chronic.parse("tomorrow 1pm")
    end
  end
end
