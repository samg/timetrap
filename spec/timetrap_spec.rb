TEST_MODE = true
require File.join(File.dirname(__FILE__), '..', 'lib', 'timetrap')
require 'spec'

OUTPUT_BUFFER = File.new('/tmp/timetrap_spec.out', 'r')
describe Timetrap do
  before :each do
    Timetrap::Entry.create_table!
    Timetrap::Meta.create_table!
    $stdout = StringIO.new
  end

  describe 'CLI' do
    describe "COMMANDS" do
      def invoke command
        Timetrap::CLI.parse command
        Timetrap::CLI.invoke
      end

      describe 'alter' do
        before do
          Timetrap.start "running entry", nil
        end
        it "should alter the description of the active period" do
          Timetrap.active_entry.note.should == 'running entry'
          invoke 'alter new description'
          Timetrap.active_entry.note.should == 'new description'
        end
      end

      describe "backend" do
        it "should open an sqlite console to the db" do
          Timetrap::CLI.should_receive(:exec).with("sqlite3 #{DB_NAME}")
          invoke 'backend'
        end
      end

      describe "display" do
        before do
          Timetrap::Entry.create( :sheet => 'SpecSheet',
            :note => 'entry 2', :start => '2008-10-03 16:00:00', :end => '2008-10-03 18:00:00'
          )
          Timetrap::Entry.create( :sheet => 'SpecSheet',
            :note => 'entry 1', :start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00'
          )
          Timetrap::Entry.create( :sheet => 'SpecSheet',
            :note => 'entry 3', :start => '2008-10-05 16:00:00', :end => '2008-10-05 18:00:00'
          )
          Timetrap::Entry.create( :sheet => 'SpecSheet',
            :note => 'entry 4', :start => '2008-10-05 18:00:00'
          )
        end
        it "should display the current timesheet" do
          Timetrap.current_sheet = 'SpecSheet'
          invoke 'display'
          $stdout.string.should == <<-OUTPUT
Timesheet SpecSheet:
          Day                Start      End        Duration   Notes
          Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
                             16:00:00 - 18:00:00   2:00:00    entry 2
                                                   4:00:00
          Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
                             18:00:00 -                       entry 4
          Total                                    6:00:00
          OUTPUT
        end
      end

      describe "format" do
        it "should export a sheet to a csv format" do
          pending
        end
      end

      describe "in" do
        it "should start the time for the current timesheet" do
          lambda do
            invoke 'in'
          end.should change(Timetrap::Entry, :count).by(1)
        end

        it "should set the note when starting a new entry" do
          invoke 'in working on something'
          Timetrap::Entry.order_by(:id).last.note.should == 'working on something'
        end

        it "should set the start when starting a new entry" do
          @time = Time.now
          Time.stub!(:now).and_return @time
          invoke 'in working on something'
          Timetrap::Entry.order_by(:id).last.start.to_i.should == @time.to_i
        end

        it "should not start the time if the timetrap is running" do
          Timetrap.stub!(:running?).and_return true
          lambda do
            invoke 'in'
          end.should_not change(Timetrap::Entry, :count)
        end

        it "should allow the sheet to be started at a certain time" do
          invoke 'in work --at "10am 2008-10-03"'
          Timetrap::Entry.order_by(:id).last.start.should == Time.parse('2008-10-03 10:00')
        end
      end

      describe "kill" do
        it "should delete a timesheet" do
          pending
        end
      end

      describe "list" do
        before do
          Timetrap::Entry.create( :sheet => 'Sheet 2', :note => 'entry 1', :start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
          Timetrap::Entry.create( :sheet => 'Sheet 1', :note => 'entry 2', :start => '2008-10-03 16:00:00', :end => '2008-10-03 18:00:00')
          Timetrap.current_sheet = 'Sheet 2'
        end
        it "should list available timesheets" do
          invoke 'list'
          $stdout.string.should == <<-OUTPUT
Timesheets:
    Sheet 1
  * Sheet 2
          OUTPUT
        end
      end

      describe "now" do
        it "should show the status of the current timesheet" do
          pending
        end
      end

      describe "out" do
        before :each do
          invoke 'in'
          @active = Timetrap.active_entry
          @now = Time.now
          Time.stub!(:now).and_return @now
        end
        it "should set the stop for the running entry" do
          @active.refresh.end.should == nil
          invoke 'out'
          @active.refresh.end.to_i.should == @now.to_i
        end

        it "should not do anything if nothing is running" do
          lambda do
            invoke 'out'
            invoke 'out'
          end.should_not raise_error
        end

        it "should allow the sheet to be stopped at a certain time" do
          invoke 'out --at "10am 2008-10-03"'
          Timetrap::Entry.order_by(:id).last.end.should == Time.parse('2008-10-03 10:00')
        end
      end
      
      describe "running" do
        it "should show all running timesheets" do
          pending
        end
      end

      describe "switch" do
        it "should switch to a new timesheet" do
          invoke 'switch sheet 1'
          Timetrap.current_sheet.should == 'sheet 1'
          invoke 'switch sheet 2'
          Timetrap.current_sheet.should == 'sheet 2'
        end
      end
    end
  end

  describe "entries" do
    it "should give the entires for a sheet" do
      e = create_entry :sheet => 'sheet'
      Timetrap.entries('sheet').all.should include(e)
    end

    def create_entry atts = {}
      Timetrap::Entry.create({
        :sheet => 's1',
        :start => Time.now,
        :end => Time.now,
        :note => 'note'}.merge(atts))
    end
  end

  describe "start" do
    it "should start an new entry" do
      @time = Time.now
      Timetrap.current_sheet = 'sheet1'
      lambda do
        Timetrap.start 'some work', @time
      end.should change(Timetrap::Entry, :count).by(1)
      Timetrap::Entry.order(:id).last.sheet.should == 'sheet1'
      Timetrap::Entry.order(:id).last.note.should == 'some work'
      Timetrap::Entry.order(:id).last.start.to_i.should == @time.to_i
      Timetrap::Entry.order(:id).last.end.should be_nil
    end

    it "should be running if it is started" do
      Timetrap.should_not be_running
      Timetrap.start 'some work', @time
      Timetrap.should be_running
    end

    it "should raise and error if it is already running" do
      lambda do
        Timetrap.start 'some work', @time
        Timetrap.start 'some work', @time
      end.should change(Timetrap::Entry, :count).by(1)
    end
  end

  describe "stop" do
    it "should stop a new entry" do
      @time = Time.now
      Timetrap.start 'some work', @time
      entry = Timetrap.active_entry
      entry.end.should be_nil
      Timetrap.stop @time
      entry.refresh.end.to_i.should == @time.to_i
    end

    it "should not be running if it is stopped" do
      Timetrap.should_not be_running
      Timetrap.start 'some work', @time
      Timetrap.stop
      Timetrap.should_not be_running
    end

    it "should not stop it twice" do
      Timetrap.start 'some work'
      e = Timetrap.active_entry
      Timetrap.stop
      time = e.refresh.end
      Timetrap.stop
      time.to_i.should == e.refresh.end.to_i
    end

  end

  describe 'switch' do
    it "should switch to a new sheet" do
      Timetrap.switch 'sheet1'
      Timetrap.current_sheet.should == 'sheet1'
      Timetrap.switch 'sheet2'
      Timetrap.current_sheet.should == 'sheet2'
    end
  end
end

describe Timetrap::Entry do
  before do
    @time = Time.now
    @entry = Timetrap::Entry.new
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
