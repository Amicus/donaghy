require 'spec_helper'

module Donaghy

  describe UnsubscribeFromEventWorker do

    let(:subscribe_event_worker) { SubscribeToEventWorker.new }
    subject { UnsubscribeFromEventWorker.new }
    let(:redis) { Donaghy.redis }

    it "should save serialized event data to redis set" do
      event_path = "/event_path/test_service/test_event/"
      queue = "test_service_queue"
      class_name = "test_class_name"

      serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

      subscribe_event_worker.perform(event_path, queue, class_name)
      is_member?(event_path, serialized_event_data).should be_true
      subject.perform(event_path, queue, class_name)
      is_member?(event_path, serialized_event_data).should be_false
    end

    def is_member?(event_path, serialized_event_data)
      Donaghy.redis.with do |redis|
        redis.sismember("donaghy_#{event_path}", serialized_event_data)
      end
    end



  end

end
