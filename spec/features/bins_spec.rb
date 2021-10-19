describe 'bins' do
  # https://github.com/samg/timetrap/pull/80
  it 'should include a t bin and an equivalent timetrap bin' do
    timetrap = File.open(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 'timetrap')))
    t = File.open(File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'bin', 't')))
    expect(t.read).to eq timetrap.read
    expect(t.stat.mode).to eq timetrap.stat.mode
  end
end
