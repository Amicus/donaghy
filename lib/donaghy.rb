require 'monitor'

module Donaghy
  ROOT_QUEUE = "global_event"
  REDIS_TIMEOUT = 5
  CONFIG_GUARD = Monitor.new

  class MissingConfigurationFile < StandardError; end

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
    return @event_publisher if @event_publisher
    CONFIG_GUARD.synchronize do
      @event_publisher = EventPublisher.new unless @event_publisher
    end
  end

  def self.logger
    return @logger if @logger
    CONFIG_GUARD.synchronize do
      @logger = Sidekiq.logger unless @logger
    end
  end

  def self.logger=(logger)
    CONFIG_GUARD.synchronize do
      @logger = logger
    end
  end

  def self.server
    CONFIG_GUARD.synchronize do
      @server ||= Server.new
    end
  end

  def self.actor_node_manager
    CONFIG_GUARD.synchronize do
      Celluloid::Actor[:actor_node_manager] ||= ActorNodeManager.new(configuration[:redis_failover].merge(zk: Donaghy.zk))
    end
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
      @using_failover = using_failover?
      logger.error("NOT USING REDIS FAILOVER BECAUSE /redis_failover/nodes does not exist") unless using_failover?
      logger.info("Donaghy configuration is now: #{configuration.inspect}")
      configuration
    end
  end

  def self.local_service_host_queue
    "donaghy_#{configuration[:name]}_#{Socket.gethostname.gsub(/\./, '_')}"
  end

  def self.default_config
    {
        redis: {
            hosts: [
                {host: "localhost", port: 6379}
            ]
        },
        zk: {
            hosts: [
                "localhost:2181"
            ]
        },
        #redis_failover: {
        #  max_failures: 2,
        #  node_strategy: 'majority',
        #  failover_strategy: 'latency',
        #  required_node_managers: 1,
        #  nodes: [
        #      { host: "localhost", port: 6379 }
        #  ]
        #},
        name: "donaghy_root",
        concurrency: 25
    }
  end

  def self.shutdown_zk
    zk.close! if zk and zk.connected?
    @zk = nil
  end

  def self.zk
    return @zk if @zk
    logger.info "setting up zk with #{configuration['zk.hosts'].join(",")}"
    CONFIG_GUARD.synchronize do
      @zk = ZK.new(configuration['zk.hosts'].join(","), timeout: 5) unless @zk
    end
  end

  def self.new_redis_connection(config = nil)
    if @using_failover
      RedisFailover::Client.new(:zk => zk)
    else
      Redis.new(url: "redis://#{config[:host]}:#{config[:port]}")
    end
  end

  def self.using_failover?
    @using_failover ||= (configuration[:redis_failover] && does_failover_node_exist?)
  end

  def self.does_failover_node_exist?
    logger.info("finding if node exists")
    zk.exists?("/redis_failover/nodes")
  end

  def self.reset_redis
    CONFIG_GUARD.synchronize do
      @redis = nil
    end
  end

  def self.redis
    return @redis if @redis
    CONFIG_GUARD.synchronize do
      unless @redis
        @redis = ConnectionPool.new(:size => configuration[:concurrency], :timeout => REDIS_TIMEOUT) { new_redis_connection(configuration['redis.hosts'].first) }
      end
    end
  end

end

at_exit do
  Donaghy.logger.info("shutting down zk in donaghy because of trapped at_exit")
  Donaghy.shutdown_zk
end

require 'active_support/core_ext/string/inflections'
require 'zk'
require 'redis_failover'
require 'sidekiq/manager'
require 'sidekiq/client'
require 'configliere'

require 'donaghy/event'
require 'donaghy/queue_finder'
require 'donaghy/event_distributer_worker'
require 'donaghy/subscribe_to_event_worker'
require 'donaghy/unsubscribe_from_event_worker'
require 'donaghy/listener_serializer'
require 'donaghy/service'
require 'donaghy/configuration'
require 'donaghy/server'
require 'donaghy/event_publisher'
require 'donaghy/actor_node_manager'


