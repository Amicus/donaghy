module Donaghy
  ROOT_QUEUE = "global_event"
  REDIS_TIMEOUT = 5

  def self.configuration
    return @configuration if @configuration
    @configuration = Configuration.new
    @configuration.defaults(default_config)
    @configuration
  end

  def self.root_event_path
    configuration[:queue_name] || "donaghy"
  end

  def self.event_publisher
    @event_publisher ||= EventPublisher.new
  end

  def self.logger
    @logger ||= Sidekiq.logger
  end

  def self.logger=(logger)
    @logger = logger
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
        },
        name: "donaghy_root",
        concurrency: 25
    }
  end

  def self.redis
    return @redis if @redis
    @redis = ConnectionPool.new(:size => configuration[:concurrency], :timeout => REDIS_TIMEOUT) { Redis.new(configuration[:redis]) }
  end

end

require 'active_support/core_ext/string/inflections'
require 'sidekiq/manager'
require 'sidekiq/client'
require 'configliere'

require 'donaghy/cli'
require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/event_distributer_worker'
require 'donaghy/subscribe_to_event_worker'
require 'donaghy/listener_serializer'
require 'donaghy/service'
require 'donaghy/configuration'
require 'donaghy/server'
require 'donaghy/event_publisher'


