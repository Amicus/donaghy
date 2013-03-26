require 'spec_helper'

module Donaghy
  describe SubscribeToEventWorker do
    let(:event_worker) { SubscribeToEventWorker.new }
    let(:event_path) { "/event_path/test_service/test_event/" }
    let(:queue) { "test_service_queue" }
    let(:class_name) { "test_class_name" }
    let(:subscription_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    it "should save serialized event data to redis set" do
      serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

      event_worker.handle_subscribe("donaghy/subscribe_to_path", subscription_event)

      Donaghy.storage.get("donaghy_#{event_path}").should include(serialized_event_data)
      Donaghy.storage.get("donaghy_event_paths").should include(event_path)
    end

  end
end
