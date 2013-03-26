require 'spec_helper'

module Donaghy
  describe Fetcher do
    let(:fake_async) { mock(:fake_async, handle_event: true) }
    let(:fake_manager) { mock(:manager, async: fake_async) }
    let(:queue) { Donaghy.root_queue }
    let(:event) { Event.from_hash(payload: { cool: true })}

    subject { Fetcher.new(fake_manager, queue) }

    after do
      subject.stop_fetching if subject.alive?
    end

    it "should distribute an event to the manager" do
      queue.publish(event)
      fake_async.should_receive(:handle_event) do |received_event|
        received_event.payload.cool.should == true
      end.once
      subject.fetch
    end

  end
end
