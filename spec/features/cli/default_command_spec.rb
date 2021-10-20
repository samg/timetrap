describe 'CLI' do
  before :each do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  context 'with default command configured' do
    it 'should invoke the default command' do
      with_stubbed_config('default_command' => 'n') do
        invoke ''
        expect($stderr.string).to include('*default: not running')
      end
    end

    it 'should allow a complicated default command' do
      with_stubbed_config('default_command' => 'display -f csv', 'formatter_search_paths' => '/tmp') do
        invoke 'in foo bar'
        invoke 'out'
        invoke ''
        expect($stdout.string).to include(',"foo bar"')
      end
    end
  end
end
