RSpec.configure do |config|
  # Use color in STDOUT
  config.color = true
  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Display 10 slowest tests after a test run
  config.profile_examples = true

  # Use the specified formatter
  # :documentation, :progress, :html, :json, CustomFormatterClass
  config.formatter = :progress

  # Specify order for spec to be run in
  # TODO: make sure all specs pass when set to :rand
  # config.order = :rand
end
