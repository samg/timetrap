# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timetrap/version'

Gem::Specification.new do |spec|
  spec.name          = "timetrap"
  spec.version       = Timetrap::VERSION
  spec.authors       = ["Sam Goldstein"]
  spec.email         = ["sgrock@gmail.org"]
  spec.summary       = "Command line time tracker"
  spec.description   = "Timetrap is a simple command line time tracker written in ruby. It provides an easy to use command line interface for tracking what you spend your time on."
  spec.homepage      = "https://github.com/samg/timetrap"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 2.1"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.9.0"
  spec.add_development_dependency "fakefs", "~> 0.20"
  # More recent versions of icalendar drop support for Ruby 1.8.7
  spec.add_development_dependency "icalendar", "~> 2.7"
  spec.add_development_dependency "json", "~> 2.3"
  spec.add_dependency "sequel", "~> 5.90.0"
  spec.add_dependency "sqlite3", "~> 1.4"

  spec.add_dependency "chronic", "~> 0.10.2"
end
