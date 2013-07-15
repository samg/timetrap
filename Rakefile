require 'rubygems/package_task'
require 'rspec/core/rake_task'
begin
  # use psych for YAML parsing if available
  require 'psych'
rescue LoadError
  # use syck
end

desc 'Default: run specs.'
task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new do |t|
  t.pattern = "./spec/**/*_spec.rb" # don't need this, it's default.
  # Put spec opts in a file named .rspec in root
end



