require 'rdoc/task'
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

Rake::RDocTask.new do |rd|
  rd.main = "README"
  rd.rdoc_dir = 'doc'
  rd.rdoc_files.include("README", "**/*.rb")
end

begin
  require 'jeweler'
  Jeweler::Tasks.new do |s|
    s.name = %q{timetrap}

    s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
    s.authors = ["Sam Goldstein"]
    s.description = %q{Command line time tracker}
    s.email = %q{sgrock@gmail.com}
    s.has_rdoc = true
    s.homepage = "http://github.com/samg/timetrap/tree/master"
    s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
    s.require_paths = ["lib"]
    s.bindir = "bin"
    s.executables = ['t']
    s.summary = %q{Command line time tracker}
    s.add_dependency("sequel", ">= 3.9.0")
    s.add_dependency("sqlite3", "~> 1.3.3")
    s.add_dependency("chronic", ">= 0.6.4")
  end
rescue LoadError
  puts "Jeweler not available."
end

