describe Timetrap do
  before do
    with_stubbed_config
  end

  def create_entry atts = {}
    Timetrap::Entry.create({
      :sheet => 'default',
      :start => Time.now,
      :end => Time.now,
      :note => 'note'}.merge(atts))
  end

  before :each do
    Timetrap::EntrySchema.create_table!
    Timetrap::MetaSchema.create_table!
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
          with_stubbed_config('default_command' => nil) do
            invoke ''
            expect($stdout.string).to include "Usage"
          end
        end
      end

      describe 'with default command configured' do
        it "should invoke the default command" do
          with_stubbed_config('default_command' => 'n') do
            invoke ''
            expect($stderr.string).to include('*default: not running')
          end
        end

        it "should allow a complicated default command" do
          with_stubbed_config('default_command' => 'display -f csv', 'formatter_search_paths' => '/tmp') do
            invoke 'in foo bar'
            invoke 'out'
            invoke ''
            expect($stdout.string).to include(',"foo bar"')
          end
        end
      end

      describe 'with an invalid command' do
        it "should tell me I'm wrong" do
          invoke 'poo'
          expect($stderr.string).to include 'Invalid command: "poo"'
        end
      end


      describe 'archive' do
        before do
          3.times do |i|
            create_entry({:note => 'grep'})
          end
          3.times do |i|
            create_entry
          end
        end

        it "should only archive entries matched by the provided regex" do
          $stdin.string = "yes\n"
          invoke 'archive --grep [g][r][e][p]'
          Timetrap::Entry.each do |e|
            if e.note == 'grep'
              expect(e.sheet).to eq '_default'
            else
              expect(e.sheet).to eq 'default'
            end
          end
        end

        it "should put the entries in a hidden sheet" do
          $stdin.string = "yes\n"
          invoke 'archive'
          Timetrap::Entry.each do |e|
            expect(e.sheet).to eq '_default'
          end
        end

        it "should leave the running entry alone" do
          invoke "in"
          $stdin.string = "yes\n"
          invoke 'archive'
          expect(Timetrap::Entry.order(:id).last.sheet).to eq 'default'
        end
      end

      describe 'config' do
        it "should write a config file" do
          FakeFS do
            FileUtils.mkdir_p(ENV['HOME'])
            config_file = ENV['HOME'] + '/.timetrap.yml'
            FileUtils.rm(config_file) if File.exist? config_file
            expect(File.exist?(config_file)).to be_falsey
            invoke "configure"
            expect(File.exist?(config_file)).to be_truthy
          end
        end

        it "should describe config file" do
          FakeFS do
            invoke "configure"
            expect($stdout.string).to eq "Config file is at \"#{ENV['HOME']}/.timetrap.yml\"\n"
          end
        end
      end

      describe 'edit' do
        before do
          Timetrap::Timer.start "running entry", nil
        end

        it "should edit the description of the active period" do
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
          invoke 'edit new description'
          expect(Timetrap::Timer.active_entry.note).to eq 'new description'
        end

        it "should allow you to move an entry to another sheet" do
          invoke 'edit --move blahblah'
          expect(Timetrap::Timer.active_entry[:sheet]).to eq 'blahblah'
          invoke 'edit -m blahblahblah'
          expect(Timetrap::Timer.active_entry[:sheet]).to eq 'blahblahblah'
        end

        it "should change the current sheet if the current entry's sheet is changed" do
          expect(Timetrap::Timer.current_sheet).not_to eq 'blahblahblah'
          invoke 'edit -m blahblahblah'
          expect(Timetrap::Timer.active_entry[:sheet]).to eq 'blahblahblah'
          expect(Timetrap::Timer.current_sheet).to eq 'blahblahblah'
        end

        it "should change the current sheet if a non current entry's sheet is changed" do
          sheet = Timetrap::Timer.current_sheet
          id = Timetrap::Timer.active_entry[:id]
          invoke 'out'
          invoke "edit -m blahblahblah -i #{id}"
          expect(Timetrap::Timer.current_sheet).to eq sheet
          expect(Timetrap::Entry[id][:sheet]).to eq 'blahblahblah'
        end

        it "should allow appending to the description of the active period" do
          with_stubbed_config('append_notes_delimiter' => '//')
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
          invoke 'edit --append new'
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry//new'
          invoke 'edit -z more'
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry//new//more'
        end

        it "should allow clearing the description of the active period" do
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
          invoke 'edit --clear'
          expect(Timetrap::Timer.active_entry.note).to eq ''
          invoke 'edit running entry'
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
          invoke 'edit -c'
          expect(Timetrap::Timer.active_entry.note).to eq ''
        end

        it "should edit the start time of the active period" do
          invoke 'edit --start "yesterday 10am"'
          expect(Timetrap::Timer.active_entry.start).to eq Chronic.parse("yesterday 10am")
          expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
        end

        it "should edit the end time of the active period" do
          entry = Timetrap::Timer.active_entry
          invoke 'edit --end "yesterday 10am"'
          expect(entry.refresh.end).to eq Chronic.parse("yesterday 10am")
          expect(entry.refresh.note).to eq 'running entry'
        end

        it "should edit a non running entry based on id" do
          not_running = Timetrap::Timer.active_entry
          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          Timetrap::Timer.start "another entry", nil

          # create a few more entries to ensure we're not falling back on "last
          # checked out of" feature.
          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          Timetrap::Timer.start "another entry", nil

          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          Timetrap::Timer.start "another entry", nil

          invoke "edit --id #{not_running.id} a new description"
          expect(not_running.refresh.note).to eq 'a new description'
        end

        it "should edit the entry last checked out of if none is running" do
          not_running = Timetrap::Timer.active_entry
          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          invoke "edit -z 'a new description'"
          expect(not_running.refresh.note).to include 'a new description'
        end

        it "should edit the entry last checked out of if none is running even if the sheet is changed" do
          not_running = Timetrap::Timer.active_entry
          Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
          invoke "edit -z 'a new description'"
          invoke "sheet another second sheet"
          expect(not_running.refresh.note).to include 'a new description'
          expect(not_running.refresh.sheet).to eq 'default'
          expect(Timetrap::Timer.current_sheet).to eq 'another second sheet'
        end

        context "with external editor" do
          let(:note_editor_command) { 'vim' }

          before do
            with_stubbed_config 'note_editor' => note_editor_command, 'append_notes_delimiter' => '//'
          end

          it "should open an editor for editing the note" do |example|
            allow(Timetrap::CLI).to receive(:system) do |editor_command|
              path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
              File.write(path[:path], "edited note")
            end
            expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
            invoke "edit"
            expect(Timetrap::Timer.active_entry.note).to eq 'edited note'
          end

          it "should pass existing note to editor" do |example|
            capture = nil
            allow(Timetrap::CLI).to receive(:system) do |editor_command|
              path = editor_command.match(/#{note_editor_command} (?<path>.*)/)

              capture = File.read(path[:path])
            end
            invoke "edit"
            expect(capture).to eq("running entry")
          end


          it "should edit a non running entry with an external editor" do |example|
            not_running = Timetrap::Timer.active_entry
            Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
            Timetrap::Timer.start "another entry", nil

            # create a few more entries to ensure we're not falling back on "last
            # checked out of" feature.
            Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
            Timetrap::Timer.start "another entry", nil

            Timetrap::Timer.stop(Timetrap::Timer.current_sheet)

            allow(Timetrap::CLI).to receive(:system) do |editor_command|
              path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
              File.write(path[:path], "id passed note")
            end

            invoke "edit --id #{not_running.id}"

            expect(not_running.refresh.note).to eq "id passed note"
          end

          it "should not call the editor if there are arguments other than --id" do
            not_running = Timetrap::Timer.active_entry
            Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
            Timetrap::Timer.start "another entry", nil

            Timetrap::Timer.stop(Timetrap::Timer.current_sheet)
            expect(Timetrap::CLI).not_to receive(:system)
            invoke "edit --id #{not_running.id} --start \"yesterday 10am\""
          end

          context "appending" do
            it "should open an editor for editing the note with -z" do |example|
              allow(Timetrap::CLI).to receive(:system) do |editor_command|
                path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
                File.write(path[:path], "appended in editor")
              end
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
              invoke "edit -z"
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry//appended in editor'
            end

            it "should open a editor for editing the note with --append" do |example|
              allow(Timetrap::CLI).to receive(:system) do |editor_command|
                path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
                File.write(path[:path], "appended in editor")
              end
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
              invoke "edit --append"
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry//appended in editor'
            end
          end

          context "clearing" do
            it "should clear the last entry with -c" do
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
              invoke "edit -c"
              expect(Timetrap::Timer.active_entry.note).to eq ''
            end

            it "should clear the last entry with --clear" do
              expect(Timetrap::Timer.active_entry.note).to eq 'running entry'
              invoke "edit --clear"
              expect(Timetrap::Timer.active_entry.note).to eq ''
            end
          end
        end
      end

      describe 'auto_sheet' do
        describe "using dotfiles auto_sheet" do
          describe 'with a .timetrap-sheet in cwd' do
            it 'should use sheet defined in dotfile' do
              Dir.chdir('spec/dotfile') do
                with_stubbed_config('auto_sheet' => 'dotfiles')
                expect(Timetrap::Timer.current_sheet).to eq 'dotfile-sheet'
              end
            end
          end
        end

        describe "using YamlCwd autosheet" do
          describe 'with cwd in auto_sheet_paths' do
            it 'should use sheet defined in config' do
              with_stubbed_config(
                'auto_sheet_paths' => {
                'a sheet' => ['/not/cwd/', Dir.getwd]
              }, 'auto_sheet' => 'yaml_cwd')
              expect(Timetrap::Timer.current_sheet).to eq 'a sheet'
            end
          end

          describe 'with ancestor of cwd in auto_sheet_paths' do
            it 'should use sheet defined in config' do
              with_stubbed_config(
                'auto_sheet_paths' => {'a sheet' => '/'},
                'auto_sheet' => 'yaml_cwd'
              )
              expect(Timetrap::Timer.current_sheet).to eq 'a sheet'
            end
          end

          describe 'with cwd not in auto_sheet_paths' do
            it 'should not use sheet defined in config' do
              with_stubbed_config(
                'auto_sheet_paths' => {
                  'a sheet' => '/not/the/current/working/directory/'
              },'auto_sheet' => 'yaml_cwd')
              expect(Timetrap::Timer.current_sheet).to eq 'default'
            end
          end

          describe 'with cwd and ancestor in auto_sheet_paths' do
            it 'should use the most specific config' do
              with_stubbed_config(
                'auto_sheet_paths' => {
                  'general sheet' => '/', 'more specific sheet' => Dir.getwd
              }, 'auto_sheet' => 'yaml_cwd')
              expect(Timetrap::Timer.current_sheet).to eq 'more specific sheet'
              with_stubbed_config(
                'auto_sheet_paths' => {
                  'more specific sheet' => Dir.getwd, 'general sheet' => '/'
                }, 'auto_sheet' => 'yaml_cwd')
              expect(Timetrap::Timer.current_sheet).to eq 'more specific sheet'
            end
          end
        end

        describe "using nested_dotfiles auto_sheet" do
          describe 'with a .timetrap-sheet in cwd' do
            it 'should use sheet defined in dotfile' do
              Dir.chdir('spec/dotfile') do
                with_stubbed_config('auto_sheet' => 'nested_dotfiles')
                expect(Timetrap::Timer.current_sheet).to eq 'dotfile-sheet'
              end
            end
            it 'should use top-most sheet found in dir heirarchy' do
              Dir.chdir('spec/dotfile/nested') do
                with_stubbed_config('auto_sheet' => 'nested_dotfiles')
                expect(Timetrap::Timer.current_sheet).to eq 'nested-sheet'
              end
            end
          end

          describe 'with no .timetrap-sheet in cwd' do
            it 'should use sheet defined in ancestor\'s dotfile' do
              Dir.chdir('spec/dotfile/nested/no-sheet') do
                with_stubbed_config('auto_sheet' => 'nested_dotfiles')
                expect(Timetrap::Timer.current_sheet).to eq 'nested-sheet'
              end
            end
          end
        end
      end

      describe "backend" do
        it "should open an sqlite console to the db" do
          expect(Timetrap::CLI).to receive(:exec).with("sqlite3 #{Timetrap::DB_NAME}")
          invoke 'backend'
        end
      end

      describe "format" do
        before do
          create_entry
        end
        it "should be deprecated" do
          invoke 'format'
          expect($stderr.string).to eq <<-WARN
The "format" command is deprecated in favor of "display". Sorry for the inconvenience.
          WARN
        end
      end

      describe "display" do
        describe "text" do
          before do
            Timetrap::Entry.create( :sheet => 'another',
              :note => 'a long entry note', :start => '2008-10-05 18:00:00'
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
            Timetrap::Entry.create( :sheet => 'LongNoteSheet',
              :note => test_long_text, :start => '2008-10-05 16:00:00', :end => '2008-10-05 18:00:00'
            )
            Timetrap::Entry.create( :sheet => 'SheetWithLineBreakNote',
              :note => "first line\nand a second line ", :start => '2008-10-05 16:00:00', :end => '2008-10-05 18:00:00'
            )

            now = local_time('2008-10-05 20:00:00')
            allow(Time).to receive(:now).and_return now
            @desired_output = <<-OUTPUT
Timesheet: SpecSheet
    Day                Start      End        Duration   Notes
    Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
                       16:00:00 - 18:00:00   2:00:00    entry 2
                                             4:00:00
    Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
                       18:00:00 -            2:00:00    entry 4
                                             4:00:00
    -----------------------------------------------------------
    Total                                    8:00:00
            OUTPUT

            @desired_output_grepped = <<-OUTPUT
Timesheet: SpecSheet
    Day                Start      End        Duration   Notes
    Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
                                             2:00:00
    Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
                                             2:00:00
    -----------------------------------------------------------
    Total                                    4:00:00
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
    -----------------------------------------------------------
    Total                                    8:00:00
            OUTPUT

            @desired_output_with_long_ids = <<-OUTPUT
Timesheet: SpecSheet
Id    Day                Start      End        Duration   Notes
3     Fri Oct 03, 2008   12:00:00 - 14:00:00   2:00:00    entry 1
2                        16:00:00 - 18:00:00   2:00:00    entry 2
                                               4:00:00
40000 Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    entry 3
5                        18:00:00 -            2:00:00    entry 4
                                               4:00:00
      -----------------------------------------------------------
      Total                                    8:00:00
            OUTPUT

            @desired_output_for_long_note_sheet = <<-OUTPUT
Timesheet: LongNoteSheet
    Day                Start      End        Duration   Notes
    Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    chatting with bob about upcoming task, district
                                                        sharing of images, how the user settings currently
                                                        works etc. Discussing the fingerprinting / cache
                                                        busting issue with CKEDITOR, suggesting perhaps
                                                        looking into forking the rubygem and seeing if we
                                                        can work in our own changes, however hard that
                                                        might be.
                                             2:00:00
    ------------------------------------------------------------------------------------------------------
    Total                                    2:00:00
            OUTPUT

            @desired_output_for_long_note_sheet_with_ids = <<-OUTPUT
Timesheet: LongNoteSheet
Id    Day                Start      End        Duration   Notes
60000 Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    chatting with bob about upcoming task, district
                                                          sharing of images, how the user settings currently
                                                          works etc. Discussing the fingerprinting / cache
                                                          busting issue with CKEDITOR, suggesting perhaps
                                                          looking into forking the rubygem and seeing if we
                                                          can work in our own changes, however hard that
                                                          might be.
                                               2:00:00
      ------------------------------------------------------------------------------------------------------
      Total                                    2:00:00
            OUTPUT

            @desired_output_for_note_with_linebreak = <<-OUTPUT
Timesheet: SheetWithLineBreakNote
    Day                Start      End        Duration   Notes
    Sun Oct 05, 2008   16:00:00 - 18:00:00   2:00:00    first line and a second line
                                             2:00:00
    --------------------------------------------------------------------------------
    Total                                    2:00:00
            OUTPUT
          end

          it "should display the current timesheet" do
            Timetrap::Timer.current_sheet = 'SpecSheet'
            invoke 'display'
            expect($stdout.string).to eq @desired_output
          end

          it "should display a non current timesheet" do
            Timetrap::Timer.current_sheet = 'another'
            invoke 'display SpecSheet'
            expect($stdout.string).to eq @desired_output
          end

          it "should display a non current timesheet based on a partial name match" do
            Timetrap::Timer.current_sheet = 'another'
            invoke 'display S'
            expect($stdout.string).to eq @desired_output
          end

          it "should prefer an exact match of a named sheet to a partial match" do
            Timetrap::Timer.current_sheet = 'Spec'
            Timetrap::Entry.create( :sheet => 'Spec',
              :note => 'entry 5', :start => '2008-10-05 18:00:00'
            )
            invoke 'display Spec'
            expect($stdout.string).to include("entry 5")
          end

          it "should only display entries that are matched by the provided regex" do
            Timetrap::Timer.current_sheet = 'SpecSheet'
            invoke 'display --grep [13]'
            expect($stdout.string).to eq @desired_output_grepped
          end

          it "should display a timesheet with ids" do
            invoke 'display S --ids'
            expect($stdout.string).to eq @desired_output_with_ids
          end

          it "should properly format a timesheet with long ids" do
            Timetrap::DB["UPDATE entries SET id = 40000 WHERE id = 4"].all
            invoke 'display S --ids'
            expect($stdout.string).to eq @desired_output_with_long_ids
          end

          it "should properly format a timesheet with no ids even if long ids are in the db" do
            Timetrap::DB["UPDATE entries SET id = 40000 WHERE id = 4"].all
            invoke 'display S'
            expect($stdout.string).to eq @desired_output
          end


          it "should display long notes nicely" do
            Timetrap::Timer.current_sheet = 'LongNoteSheet'
            invoke 'display'
            expect($stdout.string).to eq @desired_output_for_long_note_sheet
          end

          it "should display long notes with linebreaks nicely" do
            Timetrap::Timer.current_sheet = 'SheetWithLineBreakNote'
            invoke 'display'
            expect($stdout.string).to eq @desired_output_for_note_with_linebreak
          end

          it "should display long notes with ids nicely" do
            Timetrap::DB["UPDATE entries SET id = 60000 WHERE id = 6"].all
            Timetrap::Timer.current_sheet = 'LongNoteSheet'
            invoke 'display --ids'
            expect($stdout.string).to eq @desired_output_for_long_note_sheet_with_ids
          end

          it "should not display archived for all timesheets" do
            $stdin.string = "yes\n"
            invoke 'archive SpecSheet'
            $stdout.string = ''
            invoke 'display all'
            expect($stdout.string).not_to match /_SpecSheet/
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
            expect($stdout.string).to eq "yeah I did it\n"
            FileUtils.rm_r dir
          end

          it "should work when there's no note" do
            Timetrap::Entry.create( :sheet => 'SpecSheet',
              :note => nil
            )
            invoke 'd SpecSheet'
            # check it doesn't error and produces valid looking output
            expect($stdout.string).to include('Timesheet: SpecSheet')
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
            expect($stdout.string).to eq Timetrap::Entry.all.map(&:id).join(" ") + "\n"
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
            expect($stdout.string).to eq Timetrap::Entry.all.map(&:id).join(" ") + "\n"
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
            expect($stdout.string).to eq <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end

          it "should filter events by the passed dates" do
            invoke 'display --format csv --start 2008-10-03 --end 2008-10-03'
            expect($stdout.string).to eq <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
            EOF
          end

          it "should not filter events by date when none are passed" do
            invoke 'display --format csv'
            expect($stdout.string).to eq <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
            EOF
          end

          it "should escape quoted notes" do
            create_entry(
              :start => local_time_cli('2008-10-07 12:00:00'),
              :end => local_time_cli('2008-10-07 14:00:00'),
              :note => %q{"note"}
            )
            invoke 'display --format csv'
            expect($stdout.string).to eq <<-EOF
start,end,note,sheet
"2008-10-03 12:00:00","2008-10-03 14:00:00","note","default"
"2008-10-05 12:00:00","2008-10-05 14:00:00","note","default"
"2008-10-07 12:00:00","2008-10-07 14:00:00","""note""","default"
            EOF
          end
        end

        describe 'json' do
          before do
            create_entry(:start => local_time_cli('2008-10-03 12:07:00'), :end => local_time_cli('2008-10-03 14:08:00'))
            create_entry(:start => local_time_cli('2008-10-05 12:00:00'), :end => local_time_cli('2008-10-05 14:00:00'))
          end

          it "should export to json not including running items" do
            invoke 'in'
            invoke 'display -f json'
            expect(JSON.parse($stdout.string)).to eq JSON.parse(<<-EOF)
[{\"sheet\":\"default\",\"end\":\"#{local_time('2008-10-03 14:08:00')}\",\"start\":\"#{local_time('2008-10-03 12:07:00')}\",\"note\":\"note\",\"id\":1},{\"sheet\":\"default\",\"end\":\"#{local_time('2008-10-05 14:00:00')}\",\"start\":\"#{local_time('2008-10-05 12:00:00')}\",\"note\":\"note\",\"id\":2}]
            EOF
          end

          context 'with rounding on' do
            it 'should export to json with rounded output' do
              with_rounding_on do
                # rounds to 900s by default
                invoke 'display -r -f json'
                expect(JSON.parse($stdout.string)).to eq JSON.parse(<<~EOF)
                  [{\"sheet\":\"default\",\"end\":\"#{local_time('2008-10-03 14:15:00')}\",\"start\":\"#{local_time('2008-10-03 12:00:00')}\",\"note\":\"note\",\"id\":1},{\"sheet\":\"default\",\"end\":\"#{local_time('2008-10-05 14:00:00')}\",\"start\":\"#{local_time('2008-10-05 12:00:00')}\",\"note\":\"note\",\"id\":2}]
                EOF
              end
            end
          end
        end

        describe 'ical' do
          before do
            create_entry(:start => local_time_cli('2008-10-03 12:00:00'), :end => local_time_cli('2008-10-03 14:00:00'))
            create_entry(:start => local_time_cli('2008-10-05 12:00:00'), :end => local_time_cli('2008-10-05 14:00:00'))
          end

          it "should not export running items" do
            invoke 'in'
            invoke 'display --format ical'

            expect($stdout.string.scan(/BEGIN:VEVENT/).size).to eq(2)
          end

          it "should filter events by the passed dates" do
            invoke 'display --format ical --start 2008-10-03 --end 2008-10-03'
            expect($stdout.string.scan(/BEGIN:VEVENT/).size).to eq(1)
          end

          it "should not filter events by date when none are passed" do
            invoke 'display --format ical'
            expect($stdout.string.scan(/BEGIN:VEVENT/).size).to eq(2)
          end

          it "should export a sheet to an ical format" do
            invoke 'display --format ical --start 2008-10-03 --end 2008-10-03'
            desired = <<-EOF
BEGIN:VCALENDAR
VERSION:2.0
CALSCALE:GREGORIAN
METHOD:PUBLISH
PRODID:icalendar-ruby
BEGIN:VEVENT
DTEND:20081003T140000
SUMMARY:note
DTSTART:20081003T120000
END:VEVENT
END:VCALENDAR
            EOF
            desired.each_line do |line|
              expect($stdout.string).to match /#{line.chomp}/
            end
          end
        end
      end

      describe "in" do
        it "should start the time for the current timesheet" do
          expect(
            lambda do
              invoke 'in'
            end).to change(Timetrap::Entry, :count).by(1)
        end

        it "should set the note when starting a new entry" do
          invoke 'in working on something'
          expect(Timetrap::Entry.order_by(:id).last.note).to eq 'working on something'
        end

        it "should set the start when starting a new entry" do
          @time = Time.now
          allow(Time).to receive(:now).and_return @time
          invoke 'in working on something'
          expect(Timetrap::Entry.order_by(:id).last.start.to_i).to eq @time.to_i
        end

        it "should not start the time if the timetrap is running" do
          allow(Timetrap::Timer).to receive(:running?).and_return true
          expect(lambda do
            invoke 'in'
            end).not_to change(Timetrap::Entry, :count)
        end

        it "should allow the sheet to be started at a certain time" do
          invoke 'in work --at "10am 2008-10-03"'
          expect(Timetrap::Entry.order_by(:id).last.start).to eq Time.parse('2008-10-03 10:00')
        end

        it "should fail with a warning for misformatted cli options it can't parse" do
          now = Time.now
          allow(Time).to receive(:now).and_return now
          invoke 'in work --at="18 minutes ago"'
          expect(Timetrap::Entry.order_by(:id).last).to be_nil
          expect($stderr.string).to match /\w+/
        end

        it "should fail with a time argurment of total garbage" do
          now = Time.now
          allow(Time).to receive(:now).and_return now
          invoke 'in work --at "total garbage"'
          expect(Timetrap::Entry.order_by(:id).last).to be_nil
          expect($stderr.string).to match /\w+/
        end

        describe "with require_note config option set" do
          context "without a note_editor" do
            before do
              with_stubbed_config 'require_note' => true, 'note_editor' => false
            end

            it "should prompt for a note if one isn't passed" do
              $stdin.string = "an interactive note\n"
              invoke "in"
              expect($stderr.string).to include('enter a note')
              expect(Timetrap::Timer.active_entry.note).to eq "an interactive note"
            end

            it "should not prompt for a note if one is passed" do
              $stdin.string = "an interactive note\n"
              invoke "in a normal note"
              expect(Timetrap::Timer.active_entry.note).to eq "a normal note"
            end

            it "should not stop the running entry or prompt" do
              invoke "in a normal note"
              $stdin.string = "an interactive note\n"
              invoke "in"
              expect(Timetrap::Timer.active_entry.note).to eq "a normal note"
            end
          end

          context "with a note editor" do
            let(:note_editor_command) { 'vim' }
            before do
              with_stubbed_config 'require_note' => true, 'note_editor' => note_editor_command
            end

            it "should open an editor for writing the note" do |example|
              allow(Timetrap::CLI).to receive(:system) do |editor_command|
                path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
                File.write(path[:path], "written in editor")
              end
              invoke "in"
              expect($stderr.string).not_to include('enter a note')
              expect(Timetrap::Timer.active_entry.note).to eq "written in editor"
            end

            it "should preserve linebreaks from editor" do |example|
              allow(Timetrap::CLI).to receive(:system) do |editor_command|
                path = editor_command.match(/#{note_editor_command} (?<path>.*)/)
                File.write(path[:path], "line1\nline2")
              end
              invoke "in"
              expect(Timetrap::Timer.active_entry.note).to eq "line1\nline2"
            end
          end
        end

        describe "with auto_checkout config option set" do
          before do
            with_stubbed_config 'auto_checkout' => true
          end

          it "should check in normally if nothing else is running" do
            expect(Timetrap::Timer).not_to be_running #precondition
            invoke 'in'
            expect(Timetrap::Timer).to be_running
          end

          describe "with a running entry on current sheet" do
            before do
              invoke 'sheet sheet1'
              invoke 'in first task'
            end

            it "should check out and back in" do
              entry = Timetrap::Timer.active_entry('sheet1')
              invoke 'in second task'
              expect(Timetrap::Timer.active_entry('sheet1').note).to eq 'second task'
            end

            it "should tell me what it's doing" do
              invoke 'in second task'
              expect($stderr.string).to include "Checked out"
            end
          end

          describe "with a running entry on another sheet" do
            before do
              invoke 'sheet sheet1'
              invoke 'in first task'
              invoke 'sheet sheet2'
            end

            it "should check out of the running entry" do
              expect(Timetrap::Timer.active_entry('sheet1')).to be_a(Timetrap::Entry)
              invoke 'in second task'
              expect(Timetrap::Timer.active_entry('sheet1')).to be nil
            end

            it "should check out of the running entry at another time" do
              now = Time.at(Time.now - 5 * 60) # 5 minutes ago
              entry = Timetrap::Timer.active_entry('sheet1')
              expect(entry).to be_a(Timetrap::Entry)
              invoke "in -a '#{now}' second task"
              expect(entry.reload.end.to_s).to eq now.to_s
            end

            it "should check out of the running entry without having to start a new entry" do
              entry = Timetrap::Timer.active_entry('sheet1')
              expect(entry).to be_a(Timetrap::Entry)
              expect(entry.end).to be_nil
              invoke "out"
              expect(entry.reload.end).not_to be_nil
            end
          end
        end
      end

      describe "today" do
        it "should only show entries for today" do
          yesterday = Time.now - (24 * 60 * 60)
          create_entry(
            :start => yesterday,
            :end => yesterday
          )
          create_entry
          invoke 'today'
          expect($stdout.string).to include Time.now.strftime('%a %b %d, %Y')
          expect($stdout.string).not_to include yesterday.strftime('%a %b %d, %Y')
        end
      end

      describe "yesterday" do
        it "should only show entries for yesterday" do
          yesterday = Time.now - (24 * 60 * 60)
          create_entry(
            :start => yesterday,
            :end => yesterday
          )
          create_entry
          invoke 'yesterday'
          expect($stdout.string).to include yesterday.strftime('%a %b %d, %Y')
          expect($stdout.string).not_to include Time.now.strftime('%a %b %d, %Y')
        end
      end

      describe "week" do
        it "should only show entries from this week" do
          create_entry(
            :start => Time.local(2012, 2, 1, 1, 2, 3),
            :end => Time.local(2012, 2, 1, 2, 2, 3)
          )
          create_entry
          invoke 'week'
          expect($stdout.string).to include Time.now.strftime('%a %b %d, %Y')
          expect($stdout.string).not_to include 'Feb 01, 2012'
        end

        describe "with week_start config option set" do
          let(:week_start_config) { 'Tuesday' }
          before do
            with_stubbed_config 'week_start' => week_start_config
          end

          #https://github.com/samg/timetrap/issues/161
          it "should work at the end of the month" do
            expect(Date).to receive(:today).and_return(Date.new(2017 , 7, 30))

            create_entry(
              :start => Time.local(2017, 7, 29, 1, 2, 3),
              :end => Time.local(2017, 7, 29, 2, 2, 3)
            )
            invoke "week"
            expect($stdout.string).to include 'Jul 29, 2017'

          end

          it "should not show entries prior to defined start of week" do
            create_entry(
              :start => Time.local(2012, 2, 5, 1, 2, 3),
              :end => Time.local(2012, 2, 5, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 8, 1, 2, 3),
              :end => Time.local(2012, 2, 8, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 9, 1, 2, 3),
              :end => Time.local(2012, 2, 9, 2, 2, 3)
            )

            expect(Date).to receive(:today).and_return(Date.new(2012, 2, 9))
            invoke 'week'

            expect($stdout.string).to include 'Feb 08, 2012'
            expect($stdout.string).to include 'Feb 09, 2012'
            expect($stdout.string).not_to include 'Feb 05, 2012'
          end

          it "should only show entries from today if today is start of week" do
            create_entry(
              :start => Time.local(2012, 1, 31, 1, 2, 3),
              :end => Time.local(2012, 1, 31, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 5, 1, 2, 3),
              :end => Time.local(2012, 2, 5, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 7, 1, 2, 3),
              :end => Time.local(2012, 2, 7, 2, 2, 3)
            )

            expect(Date).to receive(:today).and_return(Date.new(2012, 2, 7))
            invoke 'week'

            expect($stdout.string).to include 'Feb 07, 2012'
            expect($stdout.string).not_to include 'Jan 31, 2012'
            expect($stdout.string).not_to include 'Feb 05, 2012'
          end

          it "should not show entries 7 days past start of week" do
            create_entry(
              :start => Time.local(2012, 2, 9, 1, 2, 3),
              :end => Time.local(2012, 2, 9, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 14, 1, 2, 3),
              :end => Time.local(2012, 2, 14, 2, 2, 3)
            )
            create_entry(
              :start => Time.local(2012, 2, 16, 1, 2, 3),
              :end => Time.local(2012, 2, 16, 2, 2, 3)
            )

            expect(Date).to receive(:today).and_return(Date.new(2012, 2, 7))
            invoke 'week'

            expect($stdout.string).to include 'Feb 09, 2012'
            expect($stdout.string).not_to include 'Feb 14, 2012'
            expect($stdout.string).not_to include 'Feb 16, 2012'
          end
        end
      end

      describe "month" do
        it "should display all entries for the month" do
          create_entry(
            :start => Time.local(2012, 2, 5, 1, 2, 3),
            :end => Time.local(2012, 2, 5, 2, 2, 3)
          )
          create_entry(
            :start => Time.local(2012, 2, 6, 1, 2, 3),
            :end => Time.local(2012, 2, 6, 2, 2, 3)
          )
          create_entry(
            :start => Time.local(2012, 1, 5, 1, 2, 3),
            :end => Time.local(2012, 1, 5, 2, 2, 3)
          )

          expect(Date).to receive(:today).and_return(Date.new(2012, 2, 5))
          invoke "month"


          expect($stdout.string).to include 'Feb 05, 2012'
          expect($stdout.string).to include 'Feb 06, 2012'
          expect($stdout.string).not_to include 'Jan'
        end

        it "should work in December" do
          create_entry(
            :start => Time.local(2012, 12, 5, 1, 2, 3),
            :end => Time.local(2012, 12, 5, 2, 2, 3)
          )

          expect(Date).to receive(:today).and_return(Date.new(2012, 12, 5))
          invoke "month"

          expect($stdout.string).to include 'Wed Dec 05, 2012   01:02:03 - 02:02:03'
        end
      end

      describe "kill" do
        it "should give me a chance not to fuck up" do
          entry = create_entry
          expect do
            $stdin.string = ""
            invoke "kill #{entry.sheet}"
          end.not_to change(Timetrap::Entry, :count)
        end

        it "should delete a timesheet" do
          create_entry
          entry = create_entry
          expect(lambda do
            $stdin.string = "yes\n"
            invoke "kill #{entry.sheet}"
            end).to change(Timetrap::Entry, :count).by(-2)
        end

        it "should delete an entry" do
          create_entry
          entry = create_entry
          expect(lambda do
            $stdin.string = "yes\n"
            invoke "kill --id #{entry.id}"
            end).to change(Timetrap::Entry, :count).by(-1)
        end

        it "should not prompt the user if the --yes flag is passed" do
          create_entry
          entry = create_entry
          expect(lambda do
            invoke "kill --id #{entry.id} --yes"
            end).to change(Timetrap::Entry, :count).by(-1)
        end

        describe "with a numeric sheet name" do
          before do
            now = local_time("2008-10-05 18:00:00")
            allow(Time).to receive(:now).and_return now
            create_entry( :sheet => 1234, :start => local_time_cli('2008-10-03 12:00:00'),
                         :end => local_time_cli('2008-10-03 14:00:00'))
          end

          it "should kill the sheet" do
            expect(lambda do
              invoke 'kill -y 1234'
              end).to change(Timetrap::Entry, :count).by(-1)
          end
        end
      end

      describe "list" do
        describe "with no sheets defined" do
          it "should list the default sheet" do
            invoke 'list'
            expect($stdout.string.chomp).to eq " Timesheet  Running     Today       Total Time\n*default     0:00:00     0:00:00     0:00:00"
          end
        end

        describe "with a numeric sheet name" do
          before do
            now = local_time("2008-10-05 18:00:00")
            allow(Time).to receive(:now).and_return now
            create_entry( :sheet => '1234', :start => local_time_cli('2008-10-03 12:00:00'),
                         :end => local_time_cli('2008-10-03 14:00:00'))
          end

          it "should list the sheet" do
            invoke 'list'
            expect($stdout.string).to eq " Timesheet  Running     Today       Total Time\n 1234        0:00:00     0:00:00     2:00:00\n*default     0:00:00     0:00:00     0:00:00\n"
          end
        end

        describe "with a numeric current_sheet" do
          before do
            Timetrap::Timer.current_sheet = '1234'
          end

          it "should list the sheet" do
            invoke 'list'
            expect($stdout.string).to eq  " Timesheet Running     Today       Total Time\n*1234       0:00:00     0:00:00     0:00:00\n"
          end
        end

        describe "with sheets defined" do
          before :each do
            now = local_time("2008-10-05 18:00:00")
            allow(Time).to receive(:now).and_return now
            create_entry( :sheet => 'A Longly Named Sheet 2', :start => local_time_cli('2008-10-03 12:00:00'),
                         :end => local_time_cli('2008-10-03 14:00:00'))
            create_entry( :sheet => 'A Longly Named Sheet 2', :start => local_time_cli('2008-10-03 12:00:00'),
                         :end => local_time_cli('2008-10-03 14:00:00'))
            create_entry( :sheet => 'A Longly Named Sheet 2', :start => local_time_cli('2008-10-05 12:00:00'),
                         :end => local_time_cli('2008-10-05 14:00:00'))
            create_entry( :sheet => 'A Longly Named Sheet 2', :start => local_time_cli('2008-10-05 14:00:00'),
                         :end => nil)
            create_entry( :sheet => 'Sheet 1', :start => local_time_cli('2008-10-03 16:00:00'),
                         :end => local_time_cli('2008-10-03 18:00:00'))
            Timetrap::Timer.current_sheet = 'A Longly Named Sheet 2'
          end
          it "should list available timesheets" do
            invoke 'list'
            expect($stdout.string).to eq <<-OUTPUT
 Timesheet                 Running     Today       Total Time
*A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
 Sheet 1                    0:00:00     0:00:00     2:00:00
            OUTPUT
          end

          it "should mark the last sheet with '-' if it exists" do
            invoke 'sheet Sheet 1'
            $stdout.string = ''
            invoke 'list'
            expect($stdout.string).to eq <<-OUTPUT
 Timesheet                 Running     Today       Total Time
-A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
*Sheet 1                    0:00:00     0:00:00     2:00:00
            OUTPUT
          end

          it "should not mark the last sheet with '-' if it doesn't exist" do
            invoke 'sheet Non-existent'
            invoke 'sheet Sheet 1'
            $stdout.string = ''
            invoke 'list'
            expect($stdout.string).to eq <<-OUTPUT
 Timesheet                 Running     Today       Total Time
 A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
*Sheet 1                    0:00:00     0:00:00     2:00:00
            OUTPUT
          end

          it "should include the active timesheet even if it has no entries" do
            invoke 'sheet empty sheet'
            $stdout.string = ''
            invoke 'list'
            expect($stdout.string).to eq <<-OUTPUT
 Timesheet                 Running     Today       Total Time
-A Longly Named Sheet 2     4:00:00     6:00:00    10:00:00
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
            expect($stderr.string).to eq <<-OUTPUT
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
            allow(Time).to receive(:now).and_return Time.at(60)
          end

          it "should show how long the current item is running for" do
            invoke 'now'
            expect($stdout.string).to eq <<-OUTPUT
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
              allow(Time).to receive(:now).and_return Time.at(60)
            end

            it "should show both entries" do
            invoke 'now'
            expect($stdout.string).to eq <<-OUTPUT
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
          allow(Time).to receive(:now).and_return @now
        end
        it "should set the stop for the running entry" do
          expect(@active.refresh.end).to eq nil
          invoke 'out'
          expect(@active.refresh.end.to_i).to eq @now.to_i
        end

        it "should not do anything if nothing is running" do
          expect(lambda do
            invoke 'out'
            invoke 'out'
            end).not_to raise_error
        end

        it "should allow the sheet to be stopped at a certain time" do
          invoke 'out --at "10am 2008-10-03"'
          expect(@active.refresh.end).to eq Time.parse('2008-10-03 10:00')
        end

        it "should allow you to check out of a non active sheet" do
          invoke 'sheet SomeOtherSheet'
          invoke 'in'
          @new_active = Timetrap::Timer.active_entry
          expect(@active).not_to eq @new_active
          invoke %'out #{@active.sheet} --at "10am 2008-10-03"'
          expect(@active.refresh.end).to eq Time.parse('2008-10-03 10:00')
          expect(@new_active.refresh.end).to be_nil
        end
      end

      describe "resume" do
        before :each do
          @time = Time.now
          allow(Time).to receive(:now).and_return @time

          invoke 'in A previous task that isnt last'
          @previous = Timetrap::Timer.active_entry
          invoke 'out'

          invoke 'in Some strange task'
          @last_active = Timetrap::Timer.active_entry
          invoke 'out'

          expect(Timetrap::Timer.active_entry).to be_nil
          expect(@last_active).not_to be_nil
        end

        it "should allow to resume the last active entry" do
          invoke 'resume'

          expect(Timetrap::Timer.active_entry.note).to eq(@last_active.note)
          expect(Timetrap::Timer.active_entry.start.to_s).to eq @time.to_s
        end

        it "should allow to resume the last entry from the current sheet" do
          invoke 'sheet another another'
          invoke 'in foo11998845'
          invoke 'out'
          invoke 'sheet -'
          invoke 'resume'

          expect(Timetrap::Timer.active_entry.note).to eq(@last_active.note)
          expect(Timetrap::Timer.active_entry.start.to_s).to eq @time.to_s
        end

        it "should allow to resume a specific entry" do
          invoke "resume --id #{@previous.id}"

          expect(Timetrap::Timer.active_entry.note).to eq(@previous.note)
          expect(Timetrap::Timer.active_entry.start.to_s).to eq @time.to_s
        end

        it "should allow to resume a specific entry with a given time" do
          invoke "resume --id #{@previous.id} --at \"10am 2008-10-03\""

          expect(Timetrap::Timer.active_entry.note).to eq(@previous.note)
          expect(Timetrap::Timer.active_entry.start).to eql(Time.parse('2008-10-03 10:00'))
        end

        it "should allow to resume the activity with a given time" do
          invoke 'resume --at "10am 2008-10-03"'

          expect(Timetrap::Timer.active_entry.start).to eql(Time.parse('2008-10-03 10:00'))
        end

        describe "no existing entries" do
          before(:each) do
            Timetrap::Timer.entries(Timetrap::Timer.current_sheet).each do |e|
              e.destroy
            end

            expect(Timetrap::Timer.entries(Timetrap::Timer.current_sheet)).to be_empty
            expect(Timetrap::Timer.active_entry).to be_nil
          end

        end

        describe "with only archived entries" do
          before(:each) do
            $stdin.string = "yes\n"
            invoke "archive"
            expect(Timetrap::Timer.entries(Timetrap::Timer.current_sheet)).to be_empty
            expect(Timetrap::Timer.active_entry).to be_nil
          end

          it "retrieves the note of the most recent archived entry" do
            invoke "resume"
            expect(Timetrap::Timer.active_entry).not_to be_nil
            expect(Timetrap::Timer.active_entry.note).to eq @last_active.note
            expect(Timetrap::Timer.active_entry.start.to_s).to eq @time.to_s
          end
        end

        describe "with auto_checkout config option set" do
          before do
            with_stubbed_config 'auto_checkout' => true
          end

          it "should check in normally if nothing else is running" do
            expect(Timetrap::Timer).not_to be_running #precondition
            invoke 'resume'
            expect(Timetrap::Timer).to be_running
          end

          describe "with a running entry on current sheet" do
            before do
              invoke 'sheet sheet1'
              invoke 'in first task'
            end

            it "should check out and back in" do
              entry = Timetrap::Timer.active_entry('sheet1')
              invoke 'resume second task'
              expect(Timetrap::Timer.active_entry('sheet1').id).not_to eq entry.id
            end
          end

          describe "with a running entry on another sheet" do
            before do
              invoke 'sheet sheet2'
              invoke 'in second task'
              invoke 'out'

              invoke 'sheet sheet1'
              invoke 'in first task'
              invoke 'sheet sheet2'
            end

            it "should check out of the running entry" do
              expect(Timetrap::Timer.active_entry('sheet1')).to be_a(Timetrap::Entry)
              invoke 'resume'
              expect(Timetrap::Timer.active_entry('sheet1')).to be nil
            end

            it "should check out of the running entry at another time" do
              now = Time.at(Time.now - 5 * 60) # 5 minutes ago
              entry = Timetrap::Timer.active_entry('sheet1')
              expect(entry).to be_a(Timetrap::Entry)
              invoke "resume -a '#{now}'"
              expect(entry.reload.end.to_s).to eq now.to_s
            end
          end
        end
      end

      describe "sheet" do
        it "should switch to a new timesheet" do
          invoke 'sheet sheet 1'
          expect(Timetrap::Timer.current_sheet).to eq 'sheet 1'
          invoke 'sheet sheet 2'
          expect(Timetrap::Timer.current_sheet).to eq 'sheet 2'
        end

        it "should not switch to an blank timesheet" do
          invoke 'sheet sheet 1'
          invoke 'sheet'
          expect(Timetrap::Timer.current_sheet).to eq 'sheet 1'
        end

        it "should list timesheets when there are no arguments" do
          invoke 'sheet sheet 1'
          invoke 'sheet'
          expect($stdout.string).to eq " Timesheet  Running     Today       Total Time\n*sheet 1     0:00:00     0:00:00     0:00:00\n"
        end

        it "should note if the user is already on that sheet" do
          create_entry(sheet: "sheet 1")
          invoke 'sheet sheet 1'
          invoke 'sheet sheet 1'
          expect($stderr.string).to eq "Switching to sheet \"sheet 1\"\nAlready on sheet \"sheet 1\"\n"
        end

        it "should indicate when switching to a new sheet" do
          create_entry(sheet: "foo")
          invoke 'sheet foo'
          invoke 'sheet bar'
          expect($stderr.string).to eq "Switching to sheet \"foo\"\nSwitching to sheet \"bar\" (new sheet)\n"
        end

        describe "using - to switch to the last sheet" do
          it "should warn if there isn't a sheet set" do
            expect(lambda do
              invoke 'sheet -'
              end).not_to change(Timetrap::Timer, :current_sheet)
              expect($stderr.string).to include 'LAST_SHEET is not set'
          end

          it "should switch to the last active sheet" do
            invoke 'sheet second'
            expect(lambda do
              invoke 'sheet -'
              end).to change(Timetrap::Timer, :current_sheet).
              from('second').to('default')
          end

          it "should toggle back and forth" do
            invoke 'sheet first'
            invoke 'sheet second'
            5.times do
              invoke 's -'
              expect(Timetrap::Timer.current_sheet).to eq 'first'
              invoke 's -'
              expect(Timetrap::Timer.current_sheet).to eq 'second'
            end
          end
        end
      end

      describe '--version' do
        it 'should print the version number if asked' do
          begin
            invoke '--version'
          rescue SystemExit #Getopt::Declare calls exit after --version is invoked
          end

          expect($stdout.string).to include(::Timetrap::VERSION)
        end
      end
    end
  end

  describe "entries" do
    it "should give the entires for a sheet" do
      e = create_entry :sheet => 'sheet'
      expect(Timetrap::Timer.entries('sheet').all).to include(e)
    end

  end

  describe "start" do
    it "should start an new entry" do
      @time = Time.now
      Timetrap::Timer.current_sheet = 'sheet1'
      expect(lambda do
        Timetrap::Timer.start 'some work', @time
        end).to change(Timetrap::Entry, :count).by(1)
      expect(Timetrap::Entry.order(:id).last.sheet).to eq 'sheet1'
      expect(Timetrap::Entry.order(:id).last.note).to eq 'some work'
      expect(Timetrap::Entry.order(:id).last.start.to_i).to eq @time.to_i
      expect(Timetrap::Entry.order(:id).last.end).to be_nil
    end

    it "should be running if it is started" do
      expect(Timetrap::Timer).not_to be_running
      Timetrap::Timer.start 'some work', @time
      expect(Timetrap::Timer).to be_running
    end

    it "should raise an error if it is already running" do
      expect(lambda do
        Timetrap::Timer.start 'some work', @time
        Timetrap::Timer.start 'some work', @time
        end).to raise_error(Timetrap::Timer::AlreadyRunning)
    end
  end

  describe "stop" do
    it "should stop a new entry" do
      @time = Time.now
      Timetrap::Timer.start 'some work', @time
      entry = Timetrap::Timer.active_entry
      expect(entry.end).to be_nil
      Timetrap::Timer.stop Timetrap::Timer.current_sheet, @time
      expect(entry.refresh.end.to_i).to eq @time.to_i
    end

    it "should not be running if it is stopped" do
      expect(Timetrap::Timer).not_to be_running
      Timetrap::Timer.start 'some work', @time
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(Timetrap::Timer).not_to be_running
    end

    it "should not stop it twice" do
      Timetrap::Timer.start 'some work'
      e = Timetrap::Timer.active_entry
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      time = e.refresh.end
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(time.to_i).to eq e.refresh.end.to_i
    end

    it "should track the last entry that was checked out of" do
      Timetrap::Timer.start 'some work'
      e = Timetrap::Timer.active_entry
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(Timetrap::Timer.last_checkout.id).to eq e.id
    end

  end

  describe Timetrap::Helpers do
    before do
      @helper = Object.new
      @helper.extend Timetrap::Helpers
    end
    it "should correctly format positive durations" do
      expect(@helper.format_duration(1234)).to eq " 0:20:34"
    end

    it "should correctly format negative durations" do
      expect(@helper.format_duration(-1234)).to eq "- 0:20:34"
    end
  end


  describe Timetrap::Entry do

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
          expect(Timetrap::Entry.sheets).to eq %w(another SpecSheet).sort
        end
      end


      describe 'attributes' do
        it "should have a note" do
          @entry.note = "world takeover"
          expect(@entry.note).to eq "world takeover"
        end

        it "should have a start" do
          @entry.start = @time
          expect(@entry.start.to_i).to eq @time.to_i
        end

        it "should have a end" do
          @entry.end = @time
          expect(@entry.end.to_i).to eq @time.to_i
        end

        it "should have a sheet" do
          @entry.sheet= 'name'
          expect(@entry.sheet).to eq 'name'
        end

        it "should use round start if the global round attribute is set" do
          with_rounding_on do
            with_stubbed_config('round_in_seconds' => 900) do
              @time = Chronic.parse("12:55")
              @entry.start = @time
              expect(@entry.start).to eq Chronic.parse("1")
            end
          end
        end

        it "should use round start if the global round attribute is set" do
          with_rounding_on do
            with_stubbed_config('round_in_seconds' => 900) do
              @time = Chronic.parse("12:50")
              @entry.start = @time
              expect(@entry.start).to eq Chronic.parse("12:45")
            end
          end
        end

        it "should have a rounded start" do
          with_stubbed_config('round_in_seconds' => 900) do
            @time = Chronic.parse("12:50")
            @entry.start = @time
            expect(@entry.rounded_start).to eq Chronic.parse("12:45")
          end
        end

        it "should not round nil times" do
          @entry.start = nil
          expect(@entry.rounded_start).to be_nil
        end
      end

      describe "parsing natural language times" do
        it "should set start time using english" do
          @entry.start = "yesterday 10am"
          expect(@entry.start).not_to be_nil
          expect(@entry.start).to eq Chronic.parse("yesterday 10am")
        end

        it "should set end time using english" do
          @entry.end = "tomorrow 1pm"
          expect(@entry.end).not_to be_nil
          expect(@entry.end).to eq Chronic.parse("tomorrow 1pm")
        end
      end

      describe "with times specfied like 12:12:12" do
        it "should assume a <24 hour duration" do
          @entry.start= Time.at(Time.now - 3600) # 1.hour.ago
          @entry.end = Time.at(Time.now - 300).strftime("%H:%M:%S") # ambiguous 5.minutes.ago

          # should be about 55 minutes duration.  Allow for second rollover
          # within this test.
          expect((3299..3301)).to include(@entry.duration)
        end

        it "should not assume negative durations around 12 hour length" do
          @entry.start= Time.at(Time.now - (15 * 3600)) # 15.hour.ago
          @entry.end = Time.at(Time.now - 300).strftime("%H:%M:%S") # ambiguous 5.minutes.ago

          expect((53699..53701)).to include(@entry.duration)
        end

        it "should assume a start time near the current time" do
          time = Time.at(Time.now - 300)
          @entry.start= time.strftime("%H:%M:%S") # ambiguous 5.minutes.ago

          expect(@entry.start.to_i).to eq time.to_i
        end
      end
    end

  end
  describe 'bins' do
    # https://github.com/samg/timetrap/pull/80
    it 'should include a t bin and an equivalent timetrap bin' do
      timetrap = File.open(File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 'timetrap')))
      t = File.open(File.expand_path(File.join(File.dirname(__FILE__), '..', 'bin', 't')))
      expect(t.read).to eq timetrap.read
      expect(t.stat.mode).to eq timetrap.stat.mode
    end
  end


  private

  def test_long_text
<<TEXT
chatting with bob about upcoming task, district sharing of images, how the
user settings currently works etc. Discussing the fingerprinting / cache
busting issue with CKEDITOR, suggesting perhaps looking into forking the
rubygem and seeing if we can work in our own changes, however hard that might
be.
TEXT
  end
end
