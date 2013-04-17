require 'spec_helper'

module Donaghy
  module Middleware

    describe Retry do
      let(:manager) { man = mock(:manager, name: "test_mock_manager"); man.stub_chain(:async, :event_handler_finished).and_return(true); man }
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

      it "should inc the retry count on the event" do
        ->() { event_handler.handle(event) }.should raise_error(StandardError)
        event.retry_count.should == 1
      end

      it "should acknowledge the event if it has reached the maximum number of retries" do
        event.retry_count = Retry::MAX_RETRY_ATTEMPTS
        event.should_receive(:acknowledge).exactly(1).times
        ->() { event_handler.handle(event) }.should raise_error(StandardError)
      end


    end

  end
end
