require 'spec_helper'

module Donaghy
  module Middleware

    describe Retry do
      let(:manager) { man = mock(:manager); man.stub_chain(:async, :event_handler_finished).and_return(true); man }
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
         ->() { event_handler.handle(event) }.should raise_error(StandardError)
      end

      it "should inc the retry count on the event" do
        event.retry_count.should == 1
      end

    end

  end
end
