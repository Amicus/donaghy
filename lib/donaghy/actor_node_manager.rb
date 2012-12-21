module Donaghy
  class ActorNodeManager
    include Celluloid

    attr_reader :node_manager
    def initialize(config)
      logger.info("initializing redis failover with #{config.inspect}")
      RedisFailover::Util.logger = logger
      @node_manager = RedisFailover::NodeManager.new(config)
      #this is dirty, but no way to pass in the zk to the node manager
      @node_manager.instance_variable_set(:@zk, config[:zk])
      @node_manager
    end

    def start
      logger.info("starting up the ActorNodeManager")
      Thread.new { node_manager.start }
    end

    def stop
      node_manager.shutdown
    rescue SystemExit
      true
    end

    def logger
      Donaghy.logger
    end

  end

end
