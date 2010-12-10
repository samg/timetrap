TEST_MODE = true
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'timetrap'))
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

      describe 'with no command' do
        it "should invoke --help" do
          invoke ''
          $stdout.string.should include "Usage"
        end
      end

      describe 'with an invalid command' do
        it "should tell me I'm wrong" do
          invoke 'poo'
          $stderr.string.should include 'Invalid command: "poo"'
        end
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
          Timetrap::Timer.start "running entry", nil
        end

        it "should edit the description of the active period" do
          Timetrap::Timer.active_entry.note.should == 'running entry'
          invoke 'edit new description'
          Timetrap::Timer.active_entry.note.should == 'new description'
        end

        it "should allow you to move an entry to another sheet" do
          invoke 'edit --move blahblah'
          Timetrap::Timer.active_entry[:sheet].should == 'blahblah'
          invoke 'edit -m blahblahblah'
          Timetrap::Timer.active_entry[:sheet].should == 'blahblahblah'
        end

        it "should change the current sheet if the current entry's sheet is changed" do
          Timetrap::Timer.current_sheet.should_not == 'blahblahblah'
          invoke 'edit -m blahblahblah'
          Timetrap::Timer.active_entry[:sheet].should == 'blahblahblah'
          Timetrap::Timer.current_sheet.should == 'blahblahblah'
        end

        it "should change the current sheet if a non current entry's sheet is changed" do
          sheet = Timetrap::Timer.current_sheet
          id = Timetrap::Timer.active_entry[:id]
          invoke 'out'
          invoke "edit -m blahblahblah -i #{id}"
          Timetrap::Timer.current_sheet.should == sheet
          Timetrap::Entry[id][:sheet].should == 'blahblahblah'
        end

        it "should allow appending to the description of the active period" do
          with_stubbed_config('append_notes_delimiter' => '//')
          Timetrap::Timer.active_entry.note.should == 'running entry'
          invoke 'edit --append new'
          Timetrap::Timer.active_entry.note.should == 'running entry//new'
          invoke 'edit -z more'
          Timetrap::Timer.active_entry.note.should == 'running entry//new//more'
        end

        it "should edit the start time of the active period" do
          invoke 'edit --start "yesterday 10am"'
          Timetrap::Timer.active_entry.start.should == Chronic.parse("yesterday 10am")
          Timetrap::Timer.active_entry.note.should == 'running entry'
        end

        it "should edit the end time of the active period" do
          entry = Timetrap::Timer.active_entry
          invoke 'edit --end "yesterday 10am"'
          entry.refresh.end.should == Chronic.parse("yesterday 10am")
          entry.refresh.note.should == 'running entry'
        end

        it "should edit a non running entry based on id" do
          not_running = Timetrap::Timer.active_entry
          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          Timetrap::Timer.start "another entry", nil
          invoke "edit --id #{not_running.id} a new description"
          not_running.refresh.note.should == 'a new description'
        end
      end

      describe "backend" do
        it "should open an sqlite console to the db" do
          Timetrap::CLI.should_receive(:exec).with("sqlite3 #{Timetrap::DB_NAME}")
          invoke 'backend'
        end
      end

      describe "format" do
        before do
          create_entry
        end
        it "should be deprecated" do
          invoke 'format'
          $stderr.string.should == <<-WARN
The "format" command is deprecated in favor of "display". Sorry for the inconvenience.
          WARN
        end
      end

      describe "display" do
        describe "text" do
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
            Timetrap::Timer.current_sheet = 'SpecSheet'
            invoke 'display'
            $stdout.string.should == @desired_output
          end

          it "should display a non current timesheet" do
            Timetrap::Timer.current_sheet = 'another'
            invoke 'display SpecSheet'
            $stdout.string.should == @desired_output
          end

          it "should display a non current timesheet based on a partial name match" do
            Timetrap::Timer.current_sheet = 'another'
            invoke 'display S'
            $stdout.string.should == @desired_output
          end

          it "should prefer an exact match of a named sheet to a partial match" do
            Timetrap::Timer.current_sheet = 'Spec'
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
            Timetrap::Timer.current_sheet = 'another'
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

          it "it should find a user provided formatter class and require it" do
            create_entry
            create_entry
            dir = '/tmp/timetrap/foo/bar'
            with_stubbed_config('formatter_search_paths' => dir)
            FileUtils.mkdir_p(dir)
            File.open(dir + '/baz.rb', 'w') do |f|
              f.puts <<-RUBY
                class Timetrap::Formatters::Baz
                  def initialize(entries); end
                  def output
                    "yeah I did it"
                  end
                end
              RUBY
            end
            invoke 'd -fbaz'
            $stderr.string.should == ''
            $stdout.string.should == "yeah I did it\n"
            FileUtils.rm_r dir
          end
        end

        describe "default" do
          before do
            create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
            create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
          end

          it "should allow another formatter to be set as the default" do
            with_stubbed_config 'default_formatter' => 'ids',
              'formatter_search_paths' => nil

            invoke 'd'
            $stdout.string.should == Timetrap::Entry.all.map(&:id).join(" ") + "\n"
          end
        end

        describe 'ids' do
          before do
            create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
            create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
          end

          it "should not export running items" do
            invoke 'in'
            invoke 'display --format ids'
            $stdout.string.should == Timetrap::Entry.all.map(&:id).join(" ") + "\n"
          end

        end

        describe 'csv' do
          before do
            create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
            create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
          end

          it "should not export running items" do
            invoke 'in'
            invoke 'display --format csv'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end

          it "should filter events by the passed dates" do
            invoke 'display --format csv --start 2008-10-03 --end 2008-10-03'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
            EOF
          end

          it "should not filter events by date when none are passed" do
            invoke 'display --format csv'
            $stdout.string.should == <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end
        end

        describe 'json' do
          before do
            create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
            create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
          end

          it "should export to json not including running items" do
            invoke 'in'
            invoke 'display -f json'
            JSON.parse($stdout.string).should == JSON.parse(<<-EOF)
[{\"sheet\":\"default\",\"end\":\"Fri Oct 03 14:00:00 -0700 2008\",\"start\":\"Fri Oct 03 12:00:00 -0700 2008\",\"note\":\"note\",\"id\":1},{\"sheet\":\"default\",\"end\":\"Sun Oct 05 14:00:00 -0700 2008\",\"start\":\"Sun Oct 05 12:00:00 -0700 2008\",\"note\":\"note\",\"id\":2}]
            EOF
          end
        end

        describe 'ical' do
          before do
            create_entry(:start => '2008-10-03 12:00:00', :end => '2008-10-03 14:00:00')
            create_entry(:start => '2008-10-05 12:00:00', :end => '2008-10-05 14:00:00')
          end

          it "should not export running items" do
            invoke 'in'
            invoke 'display --format ical'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(2).item
          end

          it "should filter events by the passed dates" do
            invoke 'display --format ical --start 2008-10-03 --end 2008-10-03'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(1).item
          end

          it "should not filter events by date when none are passed" do
            invoke 'display --format ical'
            $stdout.string.scan(/BEGIN:VEVENT/).should have(2).item
          end

          it "should export a sheet to an ical format" do
            invoke 'display --format ical --start 2008-10-03 --end 2008-10-03'
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
          Timetrap::Timer.stub!(:running?).and_return true
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
            Timetrap::Timer.current_sheet = 'A Longly Named Sheet 2'
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
            invoke 'sheet empty sheet'
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
          Timetrap::Timer.current_sheet = 'current sheet'
        end

        describe "when the current timesheet isn't running" do
          it "should show that it isn't running" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
*current sheet: not running
            OUTPUT
          end
        end

        describe "when the current timesheet is running" do
          before do
            invoke 'in a timesheet that is running'
            @entry = Timetrap::Timer.active_entry
            @entry.start = Time.at(0)
            @entry.save
            Time.stub!(:now).and_return Time.at(60)
          end

          it "should show how long the current item is running for" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
*current sheet: 0:01:00 (a timesheet that is running)
            OUTPUT
          end

          describe "and another timesheet is running too" do
            before do
              invoke 'sheet another-sheet'
              invoke 'in also running'
              @entry = Timetrap::Timer.active_entry
              @entry.start = Time.at(0)
              @entry.save
              Time.stub!(:now).and_return Time.at(60)
            end

            it "should show both entries" do
            invoke 'now'
            $stdout.string.should == <<-OUTPUT
 current sheet: 0:01:00 (a timesheet that is running)
*another-sheet: 0:01:00 (also running)
            OUTPUT
            end
          end
        end
      end

      describe "out" do
        before :each do
          invoke 'in'
          @active = Timetrap::Timer.active_entry
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
          invoke 'sheet SomeOtherSheet'
          invoke 'in'
          @new_active = Timetrap::Timer.active_entry
          @active.should_not == @new_active
          invoke %'out #{@active.sheet} --at "10am 2008-10-03"'
          @active.refresh.end.should == Time.parse('2008-10-03 10:00')
          @new_active.refresh.end.should be_nil
        end
      end

      describe "sheet" do
        it "should switch to a new timesheet" do
          invoke 'sheet sheet 1'
          Timetrap::Timer.current_sheet.should == 'sheet 1'
          invoke 'sheet sheet 2'
          Timetrap::Timer.current_sheet.should == 'sheet 2'
        end

        it "should not switch to an blank timesheet" do
          invoke 'sheet sheet 1'
          invoke 'sheet'
          Timetrap::Timer.current_sheet.should == 'sheet 1'
        end

        it "should list timesheets when there are no arguments" do
          invoke 'sheet sheet 1'
          invoke 'sheet'
          $stdout.string.should == " Timesheet  Running     Today       Total Time\n*sheet 1     0:00:00     0:00:00     0:00:00\n"
        end
      end
    end
  end

  describe "entries" do
    it "should give the entires for a sheet" do
      e = create_entry :sheet => 'sheet'
      Timetrap::Timer.entries('sheet').all.should include(e)
    end

  end

  describe "start" do
    it "should start an new entry" do
      @time = Time.now
      Timetrap::Timer.current_sheet = 'sheet1'
      lambda do
        Timetrap::Timer.start 'some work', @time
      end.should change(Timetrap::Entry, :count).by(1)
      Timetrap::Entry.order(:id).last.sheet.should == 'sheet1'
      Timetrap::Entry.order(:id).last.note.should == 'some work'
      Timetrap::Entry.order(:id).last.start.to_i.should == @time.to_i
      Timetrap::Entry.order(:id).last.end.should be_nil
    end

    it "should be running if it is started" do
      Timetrap::Timer.should_not be_running
      Timetrap::Timer.start 'some work', @time
      Timetrap::Timer.should be_running
    end

    it "should raise an error if it is already running" do
      lambda do
        Timetrap::Timer.start 'some work', @time
        Timetrap::Timer.start 'some work', @time
      end.should raise_error(Timetrap::Timer::AlreadyRunning)
    end
  end

  describe "stop" do
    it "should stop a new entry" do
      @time = Time.now
      Timetrap::Timer.start 'some work', @time
      entry = Timetrap::Timer.active_entry
      entry.end.should be_nil
      Timetrap::Timer.stop Timetrap::Timer.current_sheet, @time
      entry.refresh.end.to_i.should == @time.to_i
    end

    it "should not be running if it is stopped" do
      Timetrap::Timer.should_not be_running
      Timetrap::Timer.start 'some work', @time
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      Timetrap::Timer.should_not be_running
    end

    it "should not stop it twice" do
      Timetrap::Timer.start 'some work'
      e = Timetrap::Timer.active_entry
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      time = e.refresh.end
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
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
