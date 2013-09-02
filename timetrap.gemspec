# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'timetrap/version'

Gem::Specification.new do |spec|
  spec.name          = "timetrap"
  spec.version       = Timetrap::VERSION
  spec.authors       = ["Sam Goldstein"]
  spec.email         = ["sgrock@gmail.org"]
  spec.description   = "Command line time tracker"
  spec.summary       = "Command line time tracker"
  spec.homepage      = "https://github.com/samg/timetrap"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", '~> 2.13'
  spec.add_development_dependency "fakefs"
  spec.add_development_dependency "icalendar"
  spec.add_development_dependency "json"
  spec.add_dependency "sequel", "~> 4.0.0"
  spec.add_dependency "sqlite3", "~> 1.3.3"

  # Chronic 0.9 is the last version that is compatible with ruby 1.8.7
  if RUBY_VERSION == '1.8.7'
    spec.add_dependency "chronic", "~> 0.9.1"
  # but for everyone else 0.10 is a better choice
  else
    spec.add_dependency "chronic", "~> 0.10.1"
  end
end
