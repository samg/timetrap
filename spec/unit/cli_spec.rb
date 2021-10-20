describe Timetrap::CLI do
  it 'should open an sqlite console to the db' do
    expect(Timetrap::CLI).to receive(:exec).with("sqlite3 #{Timetrap::DB_NAME}")
    invoke 'backend'
  end
end
