require 'spec_helper'

module Donaghy
  #this is going to end up being more of an integration test
  describe Manager do
    let(:manager) { Manager.new(concurrency: 1, queue: Donaghy.default_queue) }

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
        manager.async.stop
        manager.wait_for_shutdown
      end
    end

    it "should publish the message" do
      Donaghy.default_queue.publish(Event.from_hash(path: event_path, payload: {cool: true }))
      Timeout.timeout(2) do
        TestWorker.finished.pop.payload.cool.should be_true
      end
    end
  end
end
