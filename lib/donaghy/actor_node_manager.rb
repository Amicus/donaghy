module Donaghy
  class ActorNodeManager
    include Celluloid

    attr_reader :node_manager
    def initialize(config)
      logger.info("initializing redis failover with #{config.inspect}")
      RedisFailover::Util.logger = logger
      @node_manager = RedisFailover::NodeManager.new(config)
    end

    #designed to be run with async
    def start
      Thread.new { node_manager.start }
    end

    def stop
      node_manager.shutdown
      node_manager.zk.close!
    rescue SystemExit
      true
    end

    def logger
      Donaghy.logger
    end

  end

end
