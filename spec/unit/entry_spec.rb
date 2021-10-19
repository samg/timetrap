describe Timetrap::Entry do
  describe 'with an instance' do
    before do
      @time = Time.now
      @entry = Timetrap::Entry.new
    end

    describe '.sheets' do
      it 'should output a list of all the available sheets' do
        Timetrap::Entry.create(sheet: 'another',
                               note: 'entry 4', start: '2008-10-05 18:00:00')
        Timetrap::Entry.create(sheet: 'SpecSheet',
                               note: 'entry 2', start: '2008-10-03 16:00:00', end: '2008-10-03 18:00:00')
        expect(Timetrap::Entry.sheets).to eq %w[another SpecSheet].sort
      end
    end

    describe 'attributes' do
      it 'should have a note' do
        @entry.note = 'world takeover'
        expect(@entry.note).to eq 'world takeover'
      end

      it 'should have a start' do
        @entry.start = @time
        expect(@entry.start.to_i).to eq @time.to_i
      end

      it 'should have a end' do
        @entry.end = @time
        expect(@entry.end.to_i).to eq @time.to_i
      end

      it 'should have a sheet' do
        @entry.sheet = 'name'
        expect(@entry.sheet).to eq 'name'
      end

      it 'should use round start if the global round attribute is set' do
        with_rounding_on do
          with_stubbed_config('round_in_seconds' => 900) do
            @time = Chronic.parse('12:55')
            @entry.start = @time
            expect(@entry.start).to eq Chronic.parse('1')
          end
        end
      end

      it 'should use round start if the global round attribute is set' do
        with_rounding_on do
          with_stubbed_config('round_in_seconds' => 900) do
            @time = Chronic.parse('12:50')
            @entry.start = @time
            expect(@entry.start).to eq Chronic.parse('12:45')
          end
        end
      end

      it 'should have a rounded start' do
        with_stubbed_config('round_in_seconds' => 900) do
          @time = Chronic.parse('12:50')
          @entry.start = @time
          expect(@entry.rounded_start).to eq Chronic.parse('12:45')
        end
      end

      it 'should not round nil times' do
        @entry.start = nil
        expect(@entry.rounded_start).to be_nil
      end
    end

    describe 'parsing natural language times' do
      it 'should set start time using english' do
        @entry.start = 'yesterday 10am'
        expect(@entry.start).not_to be_nil
        expect(@entry.start).to eq Chronic.parse('yesterday 10am')
      end

      it 'should set end time using english' do
        @entry.end = 'tomorrow 1pm'
        expect(@entry.end).not_to be_nil
        expect(@entry.end).to eq Chronic.parse('tomorrow 1pm')
      end
    end

    describe 'with times specfied like 12:12:12' do
      it 'should assume a <24 hour duration' do
        @entry.start = Time.at(Time.now - 3600) # 1.hour.ago
        @entry.end = Time.at(Time.now - 300).strftime('%H:%M:%S') # ambiguous 5.minutes.ago

        # should be about 55 minutes duration.  Allow for second rollover
        # within this test.
        expect((3299..3301)).to include(@entry.duration)
      end

      it 'should not assume negative durations around 12 hour length' do
        @entry.start = Time.at(Time.now - (15 * 3600)) # 15.hour.ago
        @entry.end = Time.at(Time.now - 300).strftime('%H:%M:%S') # ambiguous 5.minutes.ago

        expect((53_699..53_701)).to include(@entry.duration)
      end

      it 'should assume a start time near the current time' do
        time = Time.at(Time.now - 300)
        @entry.start = time.strftime('%H:%M:%S') # ambiguous 5.minutes.ago

        expect(@entry.start.to_i).to eq time.to_i
      end
    end
  end
end
