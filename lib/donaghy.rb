require 'monitor'
require 'celluloid'
require 'socket'
require 'donaghy/version'

module Donaghy
  ROOT_QUEUE = "global_event"
  CONFIG_GUARD = Monitor.new

  DONAGHY_QUEUES_PATH = 'donaghy_queues'
  DONAGHY_EVENT_PATHS = 'donaghy_events'
  PATH_PREFIX = 'donaghy_'
  LOCAL_DONAGHY_EVENT_PATHS = 'local_donaghy_events'
  LOCAL_PATH_PREFIX = 'donaghy_local_'

  class MissingConfigurationFile < StandardError; end

  def self.donaghy_env
    ENV['DONAGHY_ENV'] || (defined?(ClusterFsck) && ClusterFsck.env) || ENV['AMICUS_ENV'] || 'development'
  end

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
    @event_publisher
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
      when Array
        @storage = "Donaghy::Storage::#{configuration[:storage].first.to_s.camelize}".constantize.new(*configuration[:storage][1..-1])
      else
        @storage = configuration[:storage]
      end
    end
  end

  def self.local_storage
    return @local_storage if @local_storage
    CONFIG_GUARD.synchronize do
      return @local_storage if @local_storage
      @local_storage = Donaghy::Storage::InMemory.new unless @local_storage
    end
    @local_storage
  end

  def self.message_queue
    return @message_queue if @message_queue
    CONFIG_GUARD.synchronize do
      return @message_queue if @message_queue
      case configuration[:message_queue]
      when String, Symbol
        #TODO: requiring these things this way is kinda ugly
        if [:redis_queue, :sqs].include?(configuration[:message_queue].to_sym)
          require "donaghy/adapters/message_queue/#{configuration[:message_queue]}"
        end

        @message_queue = "Donaghy::MessageQueue::#{configuration[:message_queue].to_s.camelize}".constantize.new
      when Array
        if configuration[:message_queue].first.to_sym == :sqs
          require 'donaghy/adapters/message_queue/sqs'
        end
        @message_queue = "Donaghy::MessageQueue::#{configuration[:message_queue].first.to_s.camelize}".constantize.new(*configuration[:message_queue][1..-1])
      else
        @message_queue = configuration[:message_queue]
      end
    end
  end

  def self.queue_for(name)
    message_queue.find_by_name(name)
  end

  def self.default_queue
    queue_for(default_queue_name)
  end

  def self.default_queue_name
    "#{donaghy_env}_#{(configuration[:queue_name] || configuration[:name] || "donaghy#{rand(5000)}")}"
  end


  def self.root_queue
    queue_for("#{donaghy_env}_#{Donaghy::ROOT_QUEUE}")
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

  def self.hostname
    return @hostname if @hostname
    CONFIG_GUARD.synchronize do
      @hostname = Socket.gethostname unless @hostname
    end
    @hostname
  end

  def self.default_config
    {
        name: "#{donaghy_env}_donaghy_root",
        pwd: Dir.pwd,
        concurrency: Celluloid.cores,
        cluster_concurrency: Celluloid.cores,
        storage: default_storage,
        message_queue: default_message_queue
    }
  end

  def self.default_message_queue
    require 'donaghy/adapters/message_queue/redis_queue'
    :redis_queue
  rescue LoadError
    logger.warn("could not require redis, defaulting to in memory message queue")
    require 'donaghy/adapters/message_queue/in_memory_queue'
    :in_memory_queue
  end

  def self.default_storage
    if defined?(Moped)
      require 'donaghy/adapters/storage/mongo_storage'
      :mongo_storage
    else
      begin
        require 'donaghy/adapters/storage/redis_storage'
        :redis_storage
      rescue LoadError
        logger.warn("could not require redis, defaulting to in memory storage")
        require 'donaghy/adapters/storage/in_memory'
        :in_memory
      end
    end
  end

  def self.middleware
    @middleware ||= EventHandler.default_middleware
    yield(@middleware) if block_given?
    @middleware
  end

  #this is used mostly for testing
  def self.reset
    storage.disconnect if storage.respond_to?(:disconnect)
    message_queue.disconnect if message_queue.respond_to?(:disconnect)
    @configuration = @storage = @local_storage = @message_queue = @logger = @event_publisher = @middleware = nil
  end

  at_exit do
    message_queue.disconnect if message_queue.respond_to?(:disconnect)
    storage.disconnect if storage.respond_to?(:disconnect)
  end

end

$: << File.dirname(__FILE__)

require 'active_support/core_ext/string/inflections'
require 'configliere'

require 'donaghy/configuration'
#in memory storage is used internally
require 'donaghy/adapters/storage/in_memory'
require 'donaghy/logging'
require 'donaghy/middleware/chain'
require 'donaghy/service'
require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/remote_distributor'
require 'donaghy/event_subscriber'
require 'donaghy/event_unsubscriber'
require 'donaghy/listener_serializer'
require 'donaghy/event_publisher'

require 'donaghy/event_handler'
