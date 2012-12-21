require 'spec_helper'

module Donaghy

  describe ActorNodeManager do
    let(:manager) { Donaghy.actor_node_manager }
    let(:node_path) { "/redis_failover/nodes" }
    let(:zk) { Donaghy.zk }

    before do
      #bootstrap the paths, so we don't have to wait since we know localhost works
      if zk.exists?(node_path)
        zk.set("/redis_failover/nodes", "{\"master\":\"localhost:6379\",\"slaves\":[],\"unavailable\":[]}")
      else
        zk.create("/redis_failover/nodes", "{\"master\":\"localhost:6379\",\"slaves\":[],\"unavailable\":[]}")
      end
    end

    after do
      manager.stop
    end

    it "should work with RedisFailover" do
      manager.node_manager.should_receive(:start).and_return(true)
      manager.start
      redis = RedisFailover::Client.new(:zk => zk)
      redis.keys.should be_a(Array)
    end

    it "should start the node manager" do
      manager.node_manager.should_receive(:start).and_return(true)
      manager.start
    end

  end

end
