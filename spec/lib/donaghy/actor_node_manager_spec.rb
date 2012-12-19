require 'spec_helper'

module Donaghy

  describe ActorNodeManager do
    let(:manager) { Donaghy.actor_node_manager }

    after do
      manager.stop
    end

    it "should allow a redis failover to happen" do
      manager.start
      Donaghy.zk.exists?("/redis_failover/nodes").should be_true
      redis = RedisFailover::Client.new(:zk => Donaghy.zk)
      redis.keys.should be_a(Array)
    end

  end

end
