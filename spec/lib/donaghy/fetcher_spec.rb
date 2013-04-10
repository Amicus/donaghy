require 'spec_helper'
require 'donaghy/fetcher'

module Donaghy
  describe Fetcher do
    let(:fake_async) { mock(:fake_async, handle_event: true) }
    let(:fake_manager) { mock(:manager, name: 'test_mocked_manager', async: fake_async, alive?: true) }
    let(:queue) { Donaghy.root_queue }
    let(:event) { Event.from_hash(payload: { cool: true })}

    subject { Fetcher.new(fake_manager, queue) }

    after do
      subject.terminate if subject.alive?
    end

    it "should distribute an event to the manager and add the received_on" do
      queue.publish(event)
      fake_async.should_receive(:handle_event).once do |received_event|
        received_event.payload.cool.should == true
        received_event.received_on.should == queue
      end.once
      subject.fetch
    end

  end
end
