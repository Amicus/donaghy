source 'https://rubygems.org'

# Specify your gem's dependencies in donaghy.gemspec
gemspec

group :test do
  gem 'rake'
  gem 'rb-fsevent', '~> 0.9'
  gem 'guard-rspec'
  gem 'ci_reporter', '~> 1.7.3'
  gem 'redis', '~> 3.0.1'
  gem 'moped'
  #gem 'celluloid-redis'
  gem 'aws-sdk'
  platforms :jruby do
    gem 'torquebox-server', '~> 3.0.0'
    gem 'torquebox-cache', '~> 3.0.0'
  end
end
