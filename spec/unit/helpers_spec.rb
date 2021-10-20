describe Timetrap::Helpers do
  before do
    @helper = Object.new
    @helper.extend Timetrap::Helpers
  end
  it 'should correctly format positive durations' do
    expect(@helper.format_duration(1234)).to eq ' 0:20:34'
  end

  it 'should correctly format negative durations' do
    expect(@helper.format_duration(-1234)).to eq '- 0:20:34'
  end
end
