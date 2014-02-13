require 'spec_helper'

require "donaghy/cluster_node"

module Donaghy
  describe ClusterNode do
    let(:node) { ClusterNode.new }

    let(:event_path) { TestLoadedService::EVENT_PATH }
    let(:queue_name) { Donaghy.default_queue_name }
    let(:class_name) { "test_worker" }

    let(:test_loaded_service) { TestLoadedService }

    before do
      Donaghy.logger.info("node start")
      node.start
    end

    after do
      if node.alive?
        Donaghy.logger.info("node stop")
        (node.future.stop).value
        Donaghy.logger.info("node stopped")
      end
    end

    it "should publish the message" do
      Donaghy.event_publisher.root_trigger(event_path, payload: {cool: true })
      Timeout.timeout(2) do
        test_loaded_service.holder.pop.payload.cool.should be_true
      end
    end

    describe "with a sidekiq style worker" do
      class SomeGuy
        include Donaghy::Service
        class_attribute :holder
        self.holder = Queue.new

        def perform(*args)
          self.class.holder << args
        end
      end

      before do
        Donaghy.configuration[:services].should_not include(SomeGuy.to_s.underscore)
      end

      it "should receive them even if not subscribed" do
        Timeout.timeout(5) do
          #binding.pry
          until Donaghy.local_storage.member_of?(LOCAL_DONAGHY_EVENT_PATHS, 'donaghy_test/donaghy/sidekiq_emulator/.*')
            sleep 0.1
          end
        end
        SomeGuy.perform_async(1,2,3)
        Donaghy.logger.info("------------> starting 5 sec timeout for SomeGuy holder")
        begin
          Timeout.timeout(5) do
            SomeGuy.holder.pop.should == [1,2,3]
          end
        #rescue Timeout::Error
         # binding.pry
        end
      end
    end

  end
end
