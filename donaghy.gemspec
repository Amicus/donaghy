# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'donaghy/version'

Gem::Specification.new do |gem|
  gem.name          = "donaghy"
  gem.version       = Donaghy::VERSION
  gem.authors       = ["Topper Bowers"]
  gem.email         = ["topper@toppingdesign.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.add_dependency "sidekiq"
  gem.add_dependency "connection_pool"
  gem.add_dependency "configliere"
  gem.add_dependency("active_support")
  gem.add_dependency("i18n")


  gem.add_development_dependency "rspec"
  gem.add_development_dependency "pry"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
end
