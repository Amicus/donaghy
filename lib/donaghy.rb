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

  def self.actor_node_manager
    @actor_node_manager ||= ActorNodeManager.new(configuration[:redis_failover].merge(zk: Donaghy.zk))
  end

  def self.configuration=(opts)
    config_file = opts.delete(:config_file)
    configuration.read("/mnt/configs/donaghy_resources.yml")
    configuration.read("config/donaghy.yml")
    configuration.read(config_file) if config_file
    configuration.defaults(opts)
    configuration.defaults(queue_name: configuration[:name]) unless configuration[:queue_name]
    configuration.resolve!
    @using_failover = using_failover?
    configuration
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
    @zk = ZK.new(configuration['zk.hosts'].join(","), timeout: 5)
  end

  def self.new_redis_connection(config = nil)
    if @using_failover
      RedisFailover::Client.new(:zk => zk)
    else
      logger.error("NOT USING REDIS FAILOVER BECAUSE /redis_failover/nodes does not exist")
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
    @redis = nil
  end

  def self.redis
    return @redis if @redis
    @redis = ConnectionPool.new(:size => configuration[:concurrency], :timeout => REDIS_TIMEOUT) { new_redis_connection(configuration['redis.hosts'].first) }
  end

end

at_exit do
  Donaghy.logger.info("shutting down zk")
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


