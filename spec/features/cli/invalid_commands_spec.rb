describe 'CLI' do
  before :each do
    $stdout = StringIO.new
    $stderr = StringIO.new
  end

  context 'with an invalid command' do
    it "should tell me I'm wrong" do
      invoke 'poo'
      expect($stderr.string).to include 'Invalid command: "poo"'
    end
  end
end
