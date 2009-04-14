# -*- encoding: utf-8 -*-
Gem::Specification.new do |s|
  s.name = %q{timetrap}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Sam Goldstein"]
  s.date = %q{2009-04-14}
  s.description = %q{Command line time tracker}
  s.email = %q{sgrock@gmail.com}
  s.files = %w[README Rakefile lib/timetrap.rb bin/t spec/timetrap_spec.rb]
  s.has_rdoc = true
  s.homepage = "http://github.com/samg/timetrap/tree/master"
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.bindir = "bin"
  s.executables = ['t']
  s.rubygems_version = %q{1.3.0}
  s.summary = %q{Command line time tracker}
  s.add_dependency("sequel", ">= 2.12.0")
  s.add_dependency("chronic", ">= 0.2.3")
  s.add_dependency("getopt-declare", ">= 1.28")

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<mime-types>, [">= 1.15"])
      s.add_runtime_dependency(%q<diff-lcs>, [">= 1.1.2"])
    else
      s.add_dependency(%q<mime-types>, [">= 1.15"])
      s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
    end
  else
    s.add_dependency(%q<mime-types>, [">= 1.15"])
    s.add_dependency(%q<diff-lcs>, [">= 1.1.2"])
  end
end

