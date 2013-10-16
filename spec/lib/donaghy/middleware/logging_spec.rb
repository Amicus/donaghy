require 'spec_helper'

module Donaghy
  module Middleware

    describe Logging do
      let(:manager) { man = mock(:manager, name: 'test_mocked_manager'); man.stub_chain(:async, :event_handler_finished).and_return(true); man }
      let(:event_handler) { EventHandler.new(manager) }

      let(:event) do
        Event.from_hash({
          path: "ohhi",
          payload: {cool: true}
        })
      end

      after do
        event_handler.terminate if event_handler.alive?
      end

      before do
        Donaghy.middleware do |m|
          m.clear
          m.add Logging
        end
      end

      it "should log twice" do
        pending "we are in a fire on 10/16/2013"
        event_handler.logger.should_receive(:info).exactly(3).times
        event_handler.handle(event)
      end

    end

  end
end
