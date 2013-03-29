require 'spec_helper'

module Donaghy
  describe EventHandler do
    let(:mock_async) { mock(:real_manager, event_handler_finished: true) }
    let(:mock_manager) { mock(:async_manager, async: mock_async) }

    let(:handler) { EventHandler.new(mock_manager) }

    class TestWorker
      include Donaghy::Service
      class_attribute :finished
      self.finished = Queue.new
      receives "donaghy/test_worker", :handle_done

      def handle_done(evt)
        self.class.finished.push(evt)
      end

    end

    let(:event_path) { "donaghy/test_worker" }

    after do
      handler.terminate if handler.alive?
    end

    let(:event) do
      Event.from_hash({
          path: event_path,
          payload: { cool: true}
      })
    end

    describe "handling an event" do
      before do
        TestWorker.subscribe_to_global_events
      end

      it "should call the async event_handler_finished  on the manger" do
        mock_async.should_receive(:event_handler_finished).with(handler)
        handler.handle(event)
      end

      it "should call acknowledge on the event" do
        event.should_receive(:acknowledge).and_return(true)
        handler.handle(event)
      end

      it "should send the event to the right class" do
        #TODO: this is a little too integration-y for my liking
        event.should_receive(:heartbeat).at_least(1).times.and_return(true)
        handler.handle(event)
        Timeout.timeout(1) do
          TestWorker.finished.pop.payload[:cool].should be_true
        end
      end

    end

  end
end
