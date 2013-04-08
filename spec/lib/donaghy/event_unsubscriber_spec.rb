require 'spec_helper'

module Donaghy

  describe EventUnsubscriber do

    let(:subscribe_event_worker) { EventSubscriber.new }
    subject { EventUnsubscriber.new }

    let(:event_worker) { EventSubscriber.new }
    let(:event_path) { "/event_path/test_service/test_event/" }
    let(:queue) { "test_service_queue" }
    let(:class_name) { "test_class_name" }
    let(:unsubscribe_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    describe "when receiving an event" do
      it "should remove from remote storage" do
        serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

        subscribe_event_worker.global_subscribe_to_event(event_path, queue, class_name)
        is_member?(Donaghy.storage, event_path, serialized_event_data).should be_true

        subject.handle_unsubscribe(unsubscribe_event)
        is_member?(Donaghy.storage, event_path, serialized_event_data).should be_false
      end
    end

    describe "local unsubscribe" do
      it "should save serialized event data to storage set" do
        serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

        subscribe_event_worker.subscribe(event_path, queue, class_name)
        is_member?(Donaghy.local_storage, event_path, serialized_event_data).should be_true

        subject.unsubscribe(event_path, queue, class_name)
        is_member?(Donaghy.local_storage, event_path, serialized_event_data).should be_false
      end
    end

    def is_member?(storage, event_path, serialized_event_data)
      storage.member_of?("donaghy_#{event_path}", serialized_event_data)
    end



  end

end
