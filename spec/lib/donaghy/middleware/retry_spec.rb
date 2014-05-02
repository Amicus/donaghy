require 'spec_helper'

module Donaghy
  module Middleware

    describe Retry do
      let(:manager) do
        manager = double(:manager, name: "test_mock_manager")
        manager.stub_chain(:async, :event_handler_finished).and_return(true)
        manager
      end
      let(:event_handler) { EventHandler.new(manager) }

      let(:event) do
        Event.from_hash({
          path: "ohhi",
          payload: {cool: true}
        })
      end

      before do
        Donaghy.middleware do |m|
          m.clear
          m.add Retry
        end
      end

      after do
        event_handler.terminate if event_handler.alive?
      end

      before do
        event.stub(:path).and_raise(StandardError)
      end

      it "incs the retry count on the event" do
        expect { event_handler.handle(event) rescue nil }.to change { event.retry_count }.from(0).to(1)
      end

      it "acknowledges the event if it has reached the maximum number of retries" do
        event.retry_count = Retry::MAX_RETRY_ATTEMPTS
        expect(event).to receive(:acknowledge).exactly(1).times
        expect { event_handler.handle(event) }.to raise_error(StandardError)
      end

      it "acknowledges the event if it has been retried > 2 times and is in the kill list" do
        event.retry_count = 2
        expect(event).to receive(:acknowledge).exactly(1).times
        Donaghy.storage.add_to_set('kill_list', event.id)
        expect { event_handler.handle(event) }.to raise_error(StandardError)
      end

      it "retries when retry_count < 2 and event is in kill list" do
        event.retry_count = 1
        expect(event).not_to receive(:acknowledge)
        Donaghy.storage.add_to_set('kill_list', event.id)
        expect { event_handler.handle(event) }.to raise_error(StandardError)
      end


    end

  end
end
