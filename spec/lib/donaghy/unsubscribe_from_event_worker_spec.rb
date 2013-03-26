require 'spec_helper'

module Donaghy

  describe UnsubscribeFromEventWorker do

    let(:subscribe_event_worker) { SubscribeToEventWorker.new }
    subject { UnsubscribeFromEventWorker.new }

    let(:event_worker) { SubscribeToEventWorker.new }
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


    it "should save serialized event data to redis set" do
      serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

      subscribe_event_worker.subscribe_to_event(event_path, queue, class_name)
      is_member?(event_path, serialized_event_data).should be_true

      subject.handle_unsubscribe("donaghy/unsubscribe_from_path", unsubscribe_event)
      is_member?(event_path, serialized_event_data).should be_false
    end

    def is_member?(event_path, serialized_event_data)
      Donaghy.storage.get("donaghy_#{event_path}").include?(serialized_event_data)
    end



  end

end
