TEST_MODE = true
require File.join(File.dirname(__FILE__), '..', 'lib', 'timetrap')
require 'spec'

describe Timetrap do
  def create_entry atts = {}
    Timetrap::Entry.create({
      :sheet => 's1',
      :start => Time.now,
      :end => Time.now,
      :note => 'note'}.merge(atts))
  end

  before :each do
    Timetrap::Entry.create_table!
    Timetrap::Meta.create_table!
    $stdout = StringIO.new
    $stdin = StringIO.new
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

        it "should alter the start time of the active period" do
          invoke 'alter --start "yesterday 10am"'
          Timetrap.active_entry.start.should == Chronic.parse("yesterday 10am")
          Timetrap.active_entry.note.should == 'running entry'
        end

        it "should alter the end time of the active period" do
          entry = Timetrap.active_entry
          invoke 'alter --end "yesterday 10am"'
          entry.refresh.end.should == Chronic.parse("yesterday 10am")
          entry.refresh.note.should == 'running entry'
        end

        it "should alter a non running entry based on id" do
          not_running = Timetrap.active_entry
          Timetrap.stop
          Timetrap.start "another entry", nil
          invoke "alter --id #{not_running.id} a new description"
          not_running.refresh.note.should == 'a new description'
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
          Timetrap::Entry.create( :sheet => 'another',
            :note => 'entry 4', :start => '2008-10-05 18:00:00'
          )
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

          Time.stub!(:now).and_return Time.at(1223254800 + (60*60*2))
          @desired_output = <<-OUTPUT
Timesheet: SpecSheet
    Day                Start      End        Duration   Notes
    Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
                       16:00:00 - 18:00:00   2:00:00    entry 2
                                             4:00:00
    Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
                       18:00:00 -            2:00:00    entry 4
                                             4:00:00
    ---------------------------------------------------------
    Total                                    8:00:00
          OUTPUT

          @desired_output_with_ids = <<-OUTPUT
Timesheet: SpecSheet
Id  Day                Start      End        Duration   Notes
3   Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
2                      16:00:00 - 18:00:00   2:00:00    entry 2
                                             4:00:00
4   Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
5                      18:00:00 -            2:00:00    entry 4
                                             4:00:00
    ---------------------------------------------------------
    Total                                    8:00:00
          OUTPUT
        end

        it "should display the current timesheet" do
          Timetrap.current_sheet = 'SpecSheet'
          invoke 'display'
          $stdout.string.should == @desired_output
        end

        it "should display a non current timesheet" do
          Timetrap.current_sheet = 'another'
          invoke 'display SpecSheet'
          $stdout.string.should == @desired_output
        end

        it "should display a non current timesheet based on a partial name match" do
          Timetrap.current_sheet = 'another'
          invoke 'display S'
          $stdout.string.should == @desired_output
        end

        it "should display a timesheet with ids" do
          invoke 'display S --ids'
          $stdout.string.should == @desired_output_with_ids
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
        it "should give me a chance not to fuck up" do
          entry = create_entry
          lambda do
            $stdin.string = ""
            invoke "kill #{entry.sheet}"
          end.should_not change(Timetrap::Entry, :count).by(-1)
        end

        it "should delete a timesheet" do
          create_entry
          entry = create_entry
          lambda do
            $stdin.string = "yes\n"
            invoke "kill #{entry.sheet}"
          end.should change(Timetrap::Entry, :count).by(-2)
        end

        it "should delete an entry" do
          create_entry
          entry = create_entry
          lambda do
            $stdin.string = "yes\n"
            invoke "kill --id #{entry.id}"
          end.should change(Timetrap::Entry, :count).by(-1)
        end
      end

      describe "list" do
        before do
          Time.stub!(:now).and_return Time.parse("Oct 5 18:00:00 -0700 2008")
          create_entry( :sheet => 'A Longly Named Sheet 2', :start => '2008-10-03 12:00:00',
                       :end => '2008-10-03 14:00:00')
          create_entry( :sheet => 'A Longly Named Sheet 2', :start => '2008-10-03 12:00:00',
                       :end => '2008-10-03 14:00:00')
          create_entry( :sheet => 'A Longly Named Sheet 2', :start => '2008-10-05 12:00:00',
                       :end => '2008-10-05 14:00:00')
          create_entry( :sheet => 'A Longly Named Sheet 2', :start => '2008-10-05 14:00:00',
                       :end => nil)
          create_entry( :sheet => 'Sheet 1', :start => '2008-10-03 16:00:00',
                       :end => '2008-10-03 18:00:00')
          Timetrap.current_sheet = 'A Longly Named Sheet 2'
        end
        it "should list available timesheets" do
          invoke 'list'
          $stdout.string.should == <<-OUTPUT
 Timesheet                 Running     Today       Total Time
*A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
 Sheet 1                    0:00:00     0:00:00     2:00:00
          OUTPUT
        end
      end

      describe "now" do
        before do
          Timetrap.current_sheet = 'current sheet'
        end

        describe "when the current timesheet isn't running" do
          it "should show that it isn't running" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
current sheet: not running
            OUTPUT
          end
        end

        describe "when the current timesheet is running" do
          before do
            invoke 'in a timesheet that is running'
            @entry = Timetrap.active_entry
            @entry.stub!(:start).and_return(Time.at(0))
            Time.stub!(:now).and_return Time.at(60)
            Timetrap.stub!(:active_entry).and_return @entry
          end

          it "should show how long the current item is running for" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
current sheet: 0:01:00 (a timesheet that is running)
            OUTPUT
          end
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
        before do
          create_entry :sheet => 'one', :end => nil
          create_entry :sheet => 'two', :end => nil
        end
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

        it "should not switch to an blank timesheet" do
          invoke 'switch sheet 1'
          invoke 'switch'
          Timetrap.current_sheet.should == 'sheet 1'
        end
      end
    end
  end

  describe "entries" do
    it "should give the entires for a sheet" do
      e = create_entry :sheet => 'sheet'
      Timetrap.entries('sheet').all.should include(e)
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
