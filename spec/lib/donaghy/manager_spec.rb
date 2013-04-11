require 'spec_helper'
require 'donaghy/manager'

module Donaghy
  #this is going to end up being more of an integration test along with the cluster_node_spec
  describe Manager do
    let(:manager) { Manager.new(name: 'bob', concurrency: 2, queue: Donaghy.default_queue) }

    let(:event_path) { "donaghy/test_worker" }
    let(:queue_name) { Donaghy.default_queue_name }
    let(:class_name) { "test_worker" }

    class TestWorker
      include Donaghy::Service
      class_attribute :finished
      self.finished = Queue.new
      receives "donaghy/test_worker", :handle_done

      def handle_done(evt)
        self.class.finished.push(evt)
      end

    end

    before do
      TestWorker.subscribe_to_global_events
      manager.start
    end

    after do
      if manager.alive?
        (manager.future.stop).value
      end
    end


    describe "error states" do
      let(:my_event) do
        Event.from_hash({
            path: "donaghy/to/nowhere",
        })
      end

      it "should requeue messages when stopped an an something tries to handle work" do
        # kind hacky we're gonna set stopped but not terminate so that the test is accurately reproducing
        # the race condition where we've called stop then the fetcher tries to call into the manager
        # we're going to use an unstarted manager so that stopped? is true
        my_event.should_receive(:requeue).once
        Celluloid.logger.info("calling handle event with my_event")
        stopped_manager = Manager.new()
        stopped_manager.handle_event(my_event)
      end
    end

    it "should beat the configuration" do
      #happens through the ManagerBeater spun up at manager start
      Donaghy.storage.get(manager.beater.path_to_beat).should == Donaghy.configuration.to_hash
    end

    it "should publish the message" do
      Donaghy.default_queue.publish(Event.from_hash(path: event_path, payload: {cool: true }))
      Timeout.timeout(5) do
        TestWorker.finished.pop.payload.cool.should be_true
      end
    end
  end
end
