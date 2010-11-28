TEST_MODE = true
require File.join(File.dirname(__FILE__), '..', 'lib', 'timetrap')
require 'spec'
require 'fakefs/safe'

module Timetrap::StubConfig
  def with_stubbed_config options
    options.each do |k, v|
      Timetrap::Config.stub(:[]).with(k).and_return v
    end
  end
end

describe Timetrap do
  include Timetrap::StubConfig
  def create_entry atts = {}
    Timetrap::Entry.create({
      :sheet => 'default',
      :start => Time.now,
      :end => Time.now,
      :note => 'note'}.merge(atts))
  end


  before :each do
    Timetrap::Entry.create_table!
    Timetrap::Meta.create_table!
    $stdout = StringIO.new
    $stdin = StringIO.new
    $stderr = StringIO.new
  end

  describe 'CLI' do
    describe "COMMANDS" do
      def invoke command
        Timetrap::CLI.parse command
        Timetrap::CLI.invoke
      end

      describe 'archive' do
        before do
          3.times do |i|
            create_entry
          end
        end

        it "should put the entries in a hidden sheet" do
          $stdin.string = "yes\n"
          invoke 'archive'
          Timetrap::Entry.each do |e|
            e.sheet.should == '_default'
          end
        end

        it "should leave the running entry alone" do
          invoke "in"
          $stdin.string = "yes\n"
          invoke 'archive'
          Timetrap::Entry.order(:id).last.sheet.should == 'default'
        end
      end

      describe 'config' do
        it "should write a config file" do
          FakeFS do
            FileUtils.mkdir_p(ENV['HOME'])
            FileUtils.rm(ENV['HOME'] + '/.timetrap.yml')
            File.exist?(ENV['HOME'] + '/.timetrap.yml').should be_false
            invoke "configure"
            File.exist?(ENV['HOME'] + '/.timetrap.yml').should be_true
          end
        end

        it "should describe config file" do
          FakeFS do
            invoke "configure"
            $stdout.string.should == "Config file is at \"#{ENV['HOME']}/.timetrap.yml\"\n"
          end
        end
      end

      describe 'edit' do
        before do
          Timetrap.start "running entry", nil
        end

        it "should edit the description of the active period" do
          Timetrap.active_entry.note.should == 'running entry'
          invoke 'edit new description'
          Timetrap.active_entry.note.should == 'new description'
        end

        it "should allow you to move an entry to another sheet" do
          invoke 'edit --move blahblah'
          Timetrap.active_entry[:sheet].should == 'blahblah'
          invoke 'edit -m blahblahblah'
          Timetrap.active_entry[:sheet].should == 'blahblahblah'
        end

        it "should change the current sheet if the current entry's sheet is changed" do
          Timetrap.current_sheet.should_not == 'blahblahblah'
          invoke 'edit -m blahblahblah'
          Timetrap.active_entry[:sheet].should == 'blahblahblah'
          Timetrap.current_sheet.should == 'blahblahblah'
        end

        it "should change the current sheet if a non current entry's sheet is changed" do
          sheet = Timetrap.current_sheet
          id = Timetrap.active_entry[:id]
          invoke 'out'
          invoke "edit -m blahblahblah -i #{id}"
          Timetrap.current_sheet.should == sheet
          Timetrap::Entry[id][:sheet].should == 'blahblahblah'
        end

        it "should allow appending to the description of the active period" do
          with_stubbed_config('append_notes_delimiter' => '//')
          Timetrap.active_entry.note.should == 'running entry'
          invoke 'edit --append new'
          Timetrap.active_entry.note.should == 'running entry//new'
          invoke 'edit -z more'
          Timetrap.active_entry.note.should == 'running entry//new//more'
        end

        it "should edit the start time of the active period" do
          invoke 'edit --start "yesterday 10am"'
          Timetrap.active_entry.start.should == Chronic.parse("yesterday 10am")
          Timetrap.active_entry.note.should == 'running entry'
        end

        it "should edit the end time of the active period" do
          entry = Timetrap.active_entry
          invoke 'edit --end "yesterday 10am"'
          entry.refresh.end.should == Chronic.parse("yesterday 10am")
          entry.refresh.note.should == 'running entry'
        end

        it "should edit a non running entry based on id" do
          not_running = Timetrap.active_entry
          Timetrap.stop(Timetrap.current_sheet)
          Timetrap.start "another entry", nil
          invoke "edit --id #{not_running.id} a new description"
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

          @desired_output_for_all = <<-OUTPUT
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

Timesheet: another
    Day                Start      End        Duration   Notes
    Sun Oct 05, 2008   18:00:00 -            2:00:00    entry 4
                                             2:00:00
    ---------------------------------------------------------
    Total                                    2:00:00
-------------------------------------------------------------
Grand Total                                 10:00:00
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

        it "should display an exact match of a named sheet to a partial match" do
          Timetrap.current_sheet = 'Spec'
          Timetrap::Entry.create( :sheet => 'Spec',
            :note => 'entry 5', :start => '2008-10-05 18:00:00'
          )
          invoke 'display Spec'
          $stdout.string.should include("entry 5")
        end

        it "should display a timesheet with ids" do
          invoke 'display S --ids'
          $stdout.string.should == @desired_output_with_ids
        end

        it "should display all timesheets" do
          Timetrap.current_sheet = 'another'
          invoke 'display all'
          $stdout.string.should == @desired_output_for_all
        end

        it "should not display archived for all timesheets" do
          $stdin.string = "yes\n"
          invoke 'archive SpecSheet'
          $stdout.string = ''
          invoke 'display all'
          $stdout.string.should_not =~ /_SpecSheet/
        end
      end

      describe "format" do
        before do
          create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
          create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
        end
        describe 'csv' do

          it "should not export running items" do
            invoke 'in'
            invoke 'format --format csv'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end

          it "should filter events by the passed dates" do
            invoke 'format --format csv --start 2008-10-03 --end 2008-10-03'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
            EOF
          end

          it "should not filter events by date when none are passed" do
            invoke 'format --format csv'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end
        end

        describe 'ical' do

          it "should not export running items" do
            invoke 'in'
            invoke 'format --format ical'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(2).item
          end

          it "should filter events by the passed dates" do
            invoke 'format --format ical --start 2008-10-03 --end 2008-10-03'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(1).item
          end

          it "should not filter events by date when none are passed" do
            invoke 'format --format ical'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(2).item
          end

          it "should export a sheet to an ical format" do
            invoke 'format --format ical --start 2008-10-03 --end 2008-10-03'
            desired = <<-EOF
BEGIN:VCALENDAR
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
PRODID:iCalendar-Ruby
BEGIN:VEVENT
SEQUENCE:0
DTEND:20081003T140000
SUMMARY:note
DTSTART:20081003T120000
END:VEVENT
END:VCALENDAR
            EOF
            desired.each_line do |line|
              $stdout.string.should =~ /#{line.chomp}/
            end
          end
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

        it "should fail with a warning for misformatted cli options it can't parse" do
          now = Time.now
          Time.stub!(:now).and_return now
          invoke 'in work --at="18 minutes ago"'
          Timetrap::Entry.order_by(:id).last.should be_nil
          $stderr.string.should =~ /\w+/
        end

        it "should fail with a time argurment of total garbage" do
          now = Time.now
          Time.stub!(:now).and_return now
          invoke 'in work --at "total garbage"'
          Timetrap::Entry.order_by(:id).last.should be_nil
          $stderr.string.should =~ /\w+/
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

        it "should not prompt the user if the --yes flag is passed" do
          create_entry
          entry = create_entry
          lambda do
            invoke "kill --id #{entry.id} --yes"
          end.should change(Timetrap::Entry, :count).by(-1)
        end
      end

      describe "list" do
        describe "with no sheets defined" do
          it "should list the default sheet" do
            invoke 'list'
            $stdout.string.chomp.should == " Timesheet  Running     Today       Total Time\n*default     0:00:00     0:00:00     0:00:00"
          end
        end

        describe "with sheets defined" do
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

          it "should include the active timesheet even if it has no entries" do
            invoke 'switch empty sheet'
            $stdout.string = ''
            invoke 'list'
            $stdout.string.should == <<-OUTPUT
 Timesheet                 Running     Today       Total Time
 A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
*empty sheet                0:00:00     0:00:00     0:00:00
 Sheet 1                    0:00:00     0:00:00     2:00:00
            OUTPUT
          end
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
            @entry.start = Time.at(0)
            @entry.save
            Time.stub!(:now).and_return Time.at(60)
          end

          it "should show how long the current item is running for" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
current sheet: 0:01:00 (a timesheet that is running)
            OUTPUT
          end

          describe "and another timesheet is running too" do
            before do
              invoke 'switch another-sheet'
              invoke 'in also running'
              @entry = Timetrap.active_entry
              @entry.start = Time.at(0)
              @entry.save
              Time.stub!(:now).and_return Time.at(60)
            end

            it "should show both entries" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
current sheet: 0:01:00 (a timesheet that is running)
another-sheet: 0:01:00 (also running)
            OUTPUT
            end
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
          @active.refresh.end.should == Time.parse('2008-10-03 10:00')
        end

        it "should allow you to check out of a non active sheet" do
          invoke 'switch SomeOtherSheet'
          invoke 'in'
          @new_active = Timetrap.active_entry
          @active.should_not == @new_active
          invoke %'out #{@active.sheet} --at "10am 2008-10-03"'
          @active.refresh.end.should == Time.parse('2008-10-03 10:00')
          @new_active.refresh.end.should be_nil
        end
      end

      describe "running" do
        it "should show all running timesheets" do
          create_entry :sheet => 'one', :end => nil
          create_entry :sheet => 'two', :end => nil
          create_entry :sheet => 'three'
          invoke 'running'
          $stdout.string.should == "Running Timesheets:\n  one: note\n  two: note\n"
        end
        it "should show no runnig timesheets" do
          invoke 'running'
          $stdout.string.should == "Running Timesheets:\n"
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

    it "should raise an error if it is already running" do
      lambda do
        Timetrap.start 'some work', @time
        Timetrap.start 'some work', @time
      end.should raise_error(Timetrap::AlreadyRunning)
    end
  end

  describe "stop" do
    it "should stop a new entry" do
      @time = Time.now
      Timetrap.start 'some work', @time
      entry = Timetrap.active_entry
      entry.end.should be_nil
      Timetrap.stop Timetrap.current_sheet, @time
      entry.refresh.end.to_i.should == @time.to_i
    end

    it "should not be running if it is stopped" do
      Timetrap.should_not be_running
      Timetrap.start 'some work', @time
      Timetrap.stop Timetrap.current_sheet
      Timetrap.should_not be_running
    end

    it "should not stop it twice" do
      Timetrap.start 'some work'
      e = Timetrap.active_entry
      Timetrap.stop Timetrap.current_sheet
      time = e.refresh.end
      Timetrap.stop Timetrap.current_sheet
      time.to_i.should == e.refresh.end.to_i
    end

  end


  describe Timetrap::Entry do

    include Timetrap::StubConfig
    describe "with an instance" do
      before do
        @time = Time.now
        @entry = Timetrap::Entry.new
      end

      describe '.sheets' do
        it "should output a list of all the available sheets" do
          Timetrap::Entry.create( :sheet => 'another',
            :note => 'entry 4', :start => '2008-10-05 18:00:00'
          )
          Timetrap::Entry.create( :sheet => 'SpecSheet',
            :note => 'entry 2', :start => '2008-10-03 16:00:00', :end => '2008-10-03 18:00:00'
          )
          Timetrap::Entry.sheets.should == %w(another SpecSheet).sort
        end
      end


      describe 'attributes' do
        it "should have a note" do
          @entry.note = "world takeover"
          @entry.note.should == "world takeover"
        end

        it "should have a start" do
          @entry.start = @time
          @entry.start.to_i.should == @time.to_i
        end

        it "should have a end" do
          @entry.end = @time
          @entry.end.to_i.should == @time.to_i
        end

        it "should have a sheet" do
          @entry.sheet= 'name'
          @entry.sheet.should == 'name'
        end

        def with_rounding_on
          old_val = Timetrap::Entry.round
          begin
            Timetrap::Entry.round = true
            block_return_value = yield
          ensure
            Timetrap::Entry.round = old_val
          end
        end

        it "should use round start if the global round attribute is set" do
          with_rounding_on do
            with_stubbed_config('round_in_seconds' => 900) do
              @time = Chronic.parse("12:55am")
              @entry.start = @time
              @entry.start.should == Chronic.parse("1am")
            end
          end
        end

        it "should use round start if the global round attribute is set" do
          with_rounding_on do
            with_stubbed_config('round_in_seconds' => 900) do
              @time = Chronic.parse("12:50am")
              @entry.start = @time
              @entry.start.should == Chronic.parse("12:45am")
            end
          end
        end

        it "should have a rounded start" do
          with_stubbed_config('round_in_seconds' => 900) do
            @time = Chronic.parse("12:50am")
            @entry.start = @time
            @entry.rounded_start.should == Chronic.parse("12:45am")
          end
        end

        it "should not round nil times" do
          @entry.start = nil
          @entry.rounded_start.should be_nil
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

  end
end
