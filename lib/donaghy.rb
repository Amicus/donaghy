module Donaghy
  ROOT_QUEUE = "global_event"

  def self.configuration
    return @configuration if @configuration
    @configuration = Configuration.new
    @configuration.defaults(default_config)
    @configuration
  end

  def self.logger
    @logger ||= Sidekiq.logger
  end

  def self.server
    @server ||= Server.new
  end

  def self.configuration=(opts)
    config_file = opts.delete(:config_file)

    configuration.read("config/donaghy.yml")
    configuration.read(config_file) if config_file
    configuration.defaults(opts)
    configuration.defaults(queue_name: configuration[:name]) unless configuration[:queue_name]
    configuration.resolve!
    configuration
  end

  def self.default_config
    {
        redis: {
            url: "redis://localhost:6379"
        }
    }
  end

  def self.redis
    return @redis if @redis
    @redis = ConnectionPool.new(:size => 5, :timeout => 3) { Redis.new(configuration[:redis]) }
  end

end

require 'i18n'
require 'active_support/lazy_load_hooks'
require 'active_support/core_ext/string'
require 'active_support/core_ext/string/inflections'
#require 'active_support/core_ext/string'

require 'sidekiq/manager'
require 'sidekiq/client'
require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/event_distributer_worker'
require 'donaghy/subscribe_to_event_worker'
require 'donaghy/listener_serializer'
require 'donaghy/service'
require 'configliere'

require 'donaghy/configuration'
require 'donaghy/server'

