require 'monitor'
require 'celluloid'

module Donaghy
  ROOT_QUEUE = "global_event"
  CONFIG_GUARD = Monitor.new

  class MissingConfigurationFile < StandardError; end

  def self.configuration
    return @configuration if @configuration
    @configuration = Configuration.new
    @configuration.defaults(default_config)
    @configuration
  end

  def self.root_event_path
    configuration[:name] || configuration[:queue_name] || "donaghy"
  end

  def self.event_publisher
    return @event_publisher if @event_publisher
    CONFIG_GUARD.synchronize do
      @event_publisher = EventPublisher.new unless @event_publisher
    end
  end

  def self.logger
    return @logger if @logger
    CONFIG_GUARD.synchronize do
      @logger = Celluloid.logger unless @logger
    end
    @logger
  end

  def self.logger=(logger)
    CONFIG_GUARD.synchronize do
      @logger = Celluloid.logger = logger
    end
  end

  def self.storage
    return @storage if @storage
    CONFIG_GUARD.synchronize do
      return @storage if @storage #catches the 2nd one to get here
      case configuration[:storage]
      when String, Symbol
        @storage = "Donaghy::Storage::#{configuration[:storage].to_s.camelize}".constantize.new
      else
        @storage = configuration[:storage]
      end
    end
  end

  def self.queue
    return @queue if @queue
    CONFIG_GUARD.synchronize do
      return @queue if @queue
      case configuration[:queue]
      when String, Symbol
        @queue = "Donaghy::Queue::#{configuration[:queue].to_s.camelize}".constantize
      else
        @queue = configuration[:queue]
      end
    end
  end

  def self.queue_for(name)
    queue.find_by_name(name)
  end

  def self.configuration=(opts)
    CONFIG_GUARD.synchronize do
      config_file = opts[:config_file]
      configuration.read("/mnt/configs/donaghy_resources.yml")
      configuration.read("config/donaghy.yml")
      if config_file
        raise MissingConfigurationFile, "Config file: #{config_file} does not exist" unless File.exists?(config_file)
        configuration.read(config_file)
      end
      configuration.defaults(opts)
      configuration.defaults(queue_name: configuration[:name]) unless configuration[:queue_name]
      version_file_path = "config/version.txt"
      if File.exists?(version_file_path)
        configuration["#{configuration[:name]}_version"] = File.read(version_file_path)
      end
      configuration.resolve!
      logger.info("Donaghy configuration is now: #{configuration.inspect}")
      configuration
    end
  end

  def self.local_service_host_queue
    "donaghy_#{configuration[:name]}_#{Socket.gethostname.gsub(/\./, '_')}"
  end

  def self.default_config
    {
        name: "donaghy_root",
        concurrency: 25,
        storage: :in_memory,
        queue: :sqs
    }
  end

end

$: << File.dirname(__FILE__)

require 'active_support/core_ext/string/inflections'
require 'configliere'

require 'donaghy/configuration'
require 'donaghy/service'
require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/event_distributer_worker'
require 'donaghy/subscribe_to_event_worker'
require 'donaghy/unsubscribe_from_event_worker'
require 'donaghy/listener_serializer'
require 'donaghy/event_publisher'
require 'donaghy/storage'


