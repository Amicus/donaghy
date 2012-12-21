require 'spec_helper'

module Donaghy

  describe ActorNodeManager do
    let(:manager) { Donaghy.actor_node_manager }

    after do
      manager.stop
    end

    it "should allow a redis failover to happen" do
      manager.start
      path = "/redis_failover/nodes"
      Donaghy.logger.info("waiting for #{path}")
      wait_for(path)

      zk.exists?(path).should be_true
      redis = RedisFailover::Client.new(:zk => Donaghy.zk)
      redis.keys.should be_a(Array)
    end

    def wait_for(path)
      queue = Queue.new
      zk.register(path) do |event|
        queue.push(:path_exists)
      end
      queue.push(:path_exists) if zk.exists?(path, :watch => true)
      Timeout.timeout(10) do
        queue.pop.should == :path_exists
      end
    end

    def zk
      Donaghy.zk
    end

  end

end
