source 'https://rubygems.org'

# Specify your gem's dependencies in donaghy.gemspec
gemspec

group :test do
  gem 'rake'
  gem 'rb-fsevent', '~> 0.9'
  gem 'guard-rspec'
  gem 'ci_reporter', '~> 1.7.3'
  platforms :jruby do
    gem 'torquebox-server', '~> 2.3.0'
    gem 'torquebox-cache', '~> 2.3.0'
  end
end
