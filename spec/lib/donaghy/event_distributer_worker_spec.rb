require 'spec_helper'

module Donaghy

  describe EventDistributerWorker do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:event) { Event.new(path: event_path, payload: true)}
    let(:queue_finder) { QueueFinder.new(event_path)}
    let(:mock_queue) { mock(:queue, publish: true)}
    let(:subscription_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    class KlassHandler
      include Donaghy::Service
      donaghy_options = {:queue => "testQueue"}
    end

    before do
      SubscribeToEventWorker.new.handle_subscribe("donaghy/subscribe_to_path", subscription_event)
    end

    it "should distribute work" do
      Donaghy.should_receive(:queue_for).with(queue).and_return(mock_queue)
      mock_queue.should_receive(:publish).with(an_instance_of(Event)).and_return(true)
      EventDistributerWorker.new.handle_distribution(event_path, event)
    end

  end


end
