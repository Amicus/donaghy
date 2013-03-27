require 'spec_helper'

module Donaghy

  describe RemoteDistributor do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:event) { Event.new(path: event_path, payload: true)}
    let(:queue_finder) { QueueFinder.new(event_path)}
    let(:mock_queue) { mock(:message_queue, publish: true)}

    before do
      EventSubscriber.new.global_subscribe_to_event(event_path, queue, class_name)
    end

    it "should distribute work" do
      Donaghy.should_receive(:queue_for).with(queue).and_return(mock_queue)
      mock_queue.should_receive(:publish).with(an_instance_of(Event)).and_return(true)
      RemoteDistributor.new.handle_distribution(event)
    end

    it "shouldn't error when no subscription" do
      Donaghy.storage.flush
      ->() { RemoteDistributor.new.handle_distribution(event) }.should_not raise_error
    end

  end


end
