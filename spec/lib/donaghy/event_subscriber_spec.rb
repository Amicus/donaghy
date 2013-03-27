require 'spec_helper'

module Donaghy
  describe EventSubscriber do
    let(:event_worker) { EventSubscriber.new }
    let(:event_path) { "/event_path/test_service/test_event/" }
    let(:queue) { "test_service_queue" }
    let(:class_name) { "test_class_name" }

    let(:serialized_event_data) { ListenerSerializer.dump(queue: queue, class_name: class_name) }
    let(:subscription_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    describe "when just subscribing" do

      it "should store the subscription locally and fire an event" do
        mock_queue = mock(:queue, publish: true)
        Donaghy.stub(:root_queue).and_return(mock_queue)
        mock_queue.should_receive(:publish).with(an_instance_of(Event))
        EventSubscriber.new.subscribe(event_path, queue, class_name)
        assert_has_subscription(Donaghy.local_storage, event_path, serialized_event_data)
      end

    end

    describe "when receiving a remote event to handle a subscription" do
      it "should save serialized event data to storage set" do
        event_worker.handle_subscribe("donaghy/subscribe_to_path", subscription_event)
        assert_has_subscription(Donaghy.storage, event_path, serialized_event_data)
      end
    end


    def assert_has_subscription(storage, path, data)
      storage.get("donaghy_#{path}").should include(data)
      storage.get("donaghy_event_paths").should include(path)
    end

  end
end
