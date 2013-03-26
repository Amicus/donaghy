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

  def self.message_queue
    return @message_queue if @message_queue
    CONFIG_GUARD.synchronize do
      return @message_queue if @message_queue
      case configuration[:message_queue]
      when String, Symbol
        @message_queue = "Donaghy::MessageQueue::#{configuration[:message_queue].to_s.camelize}".constantize
      else
        @message_queue = configuration[:message_queue]
      end
    end
  end

  def self.queue_for(name)
    message_queue.find_by_name(name)
  end

  def self.default_queue
    return @default_queue if @default_queue
    CONFIG_GUARD.synchronize do
      @default_queue = queue_for(default_queue_name) unless @default_queue
    end
    @default_queue
  end

  def self.default_queue_name
    configuration[:queue_name] || configuration[:name] || "donaghy#{rand(5000)}"
  end


  def self.root_queue
    return @root_queue if @root_queue
    CONFIG_GUARD.synchronize do
      @root_queue = queue_for(Donaghy::ROOT_QUEUE) unless @root_queue
    end
    @root_queue
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
        concurrency: 4,
        storage: :in_memory,
        message_queue: :sqs
    }
  end

  def self.reset
    @root_queue = @default_queue = @configuration = @storage = @message_queue = @logger = @event_publisher = nil
  end

end

$: << File.dirname(__FILE__)

require 'active_support/core_ext/string/inflections'
require 'configliere'

require 'donaghy/configuration'
require 'donaghy/storage'
require 'donaghy/message_queue'
require 'donaghy/logging'
require 'donaghy/service'
require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/remote_distributor'
require 'donaghy/subscribe_to_event_worker'
require 'donaghy/unsubscribe_from_event_worker'
require 'donaghy/listener_serializer'
require 'donaghy/event_publisher'

require 'donaghy/fetcher'
require 'donaghy/event_handler'
require 'donaghy/manager'
