describe Timetrap::Timer do
  before :each do
    Timetrap::EntrySchema.create_table!
  end

  describe 'entries' do
    it 'should give the entires for a sheet' do
      e = create_entry sheet: 'sheet'
      expect(Timetrap::Timer.entries('sheet').all).to include(e)
    end
  end

  describe 'start' do
    it 'should start an new entry' do
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

    it 'should be running if it is started' do
      expect(Timetrap::Timer).not_to be_running
      Timetrap::Timer.start 'some work', @time
      expect(Timetrap::Timer).to be_running
    end

    it 'should raise an error if it is already running' do
      expect(lambda do
               Timetrap::Timer.start 'some work', @time
               Timetrap::Timer.start 'some work', @time
             end).to raise_error(Timetrap::Timer::AlreadyRunning)
    end
  end

  describe 'stop' do
    it 'should stop a new entry' do
      @time = Time.now
      Timetrap::Timer.start 'some work', @time
      entry = Timetrap::Timer.active_entry
      expect(entry.end).to be_nil
      Timetrap::Timer.stop Timetrap::Timer.current_sheet, @time
      expect(entry.refresh.end.to_i).to eq @time.to_i
    end

    it 'should not be running if it is stopped' do
      expect(Timetrap::Timer).not_to be_running
      Timetrap::Timer.start 'some work', @time
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(Timetrap::Timer).not_to be_running
    end

    it 'should not stop it twice' do
      Timetrap::Timer.start 'some work'
      e = Timetrap::Timer.active_entry
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      time = e.refresh.end
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(time.to_i).to eq e.refresh.end.to_i
    end

    it 'should track the last entry that was checked out of' do
      Timetrap::Timer.start 'some work'
      e = Timetrap::Timer.active_entry
      Timetrap::Timer.stop Timetrap::Timer.current_sheet
      expect(Timetrap::Timer.last_checkout.id).to eq e.id
    end
  end
end
