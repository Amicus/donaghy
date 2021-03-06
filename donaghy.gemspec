# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'donaghy/version'

Gem::Specification.new do |gem|
  gem.name          = "donaghy"
  gem.version       = Donaghy::VERSION
  gem.authors       = ["Topper Bowers"]
  gem.email         = ["topper@amicushq.com.com"]
  gem.description   = %q{gem to run services on aws}
  gem.summary       = %q{gem to run services on aws}
  gem.homepage      = "https://github.com/Amicus/donaghy"

  gem.add_dependency "celluloid", "~> 0.15"
  gem.add_dependency "hashie"
  gem.add_dependency "configliere"
  gem.add_dependency "connection_pool"
  gem.add_dependency "activesupport", ">= 3.0.0"
  gem.add_dependency "commander", "~> 4.1.0"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "timecop"
  gem.add_development_dependency "pry"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
