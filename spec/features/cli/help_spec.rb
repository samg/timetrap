describe 'CLI --help' do
  before :each do
    $stdout = StringIO.new
  end

  context 'with no command' do
    it 'should invoke --help' do
      with_stubbed_config('default_command' => nil) do
        invoke ''
        expect($stdout.string).to include 'Usage'
      end
    end
  end
end
