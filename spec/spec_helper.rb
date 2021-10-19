# Constants
TEST_MODE = true

# Vendors
require 'fakefs/safe'

# Load support files from the spec/support directory
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

# timetrap
require File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib', 'timetrap'))

# Config
RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Display 10 slowest tests after a test run
  config.profile_examples = false

  # Use the specified formatter
  # :documentation, :progress, :html, :json, CustomFormatterClass
  config.formatter = :progress

  # Specify order for spec to be run in
  # TODO: make sure all specs pass when set to :rand
  # config.order = :rand

  # We are stubbing stderr and stdout, if you want to capture
  # any of your output in tests, simply add :write_stdout_stderr => true
  # as metadata to the end of your test
  config.after(:each, write_stdout_stderr: true) do
    $stderr.rewind
    $stdout.rewind
    File.write("stderr.txt", $stderr.read)
    File.write("stdout.txt", $stdout.read)
  end
end
