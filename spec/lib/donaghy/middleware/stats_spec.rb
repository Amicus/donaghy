require 'spec_helper'

module Donaghy
  module Middleware

    describe Stats do
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
          m.add Stats
        end
      end

      after do
        event_handler.terminate if event_handler.alive?
      end

      it "should inc the complete count" do
        event_handler.handle(event)
        Donaghy.storage.get('complete').should == 1
      end

      it "should have in progress back down to 0 when its done" do
        event_handler.handle(event)
        Donaghy.storage.get('inprogress').should == 0
      end

    end

  end
end
