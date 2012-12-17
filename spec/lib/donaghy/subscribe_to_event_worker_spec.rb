require 'spec_helper'

module Donaghy
  describe SubscribeToEventWorker do
    let(:event_worker) { SubscribeToEventWorker.new }
    let(:redis) { Donaghy.redis }

    it "should save serialized event data to redis set" do
      event_path = "/event_path/test_service/test_event/"
      queue = "test_service_queue"
      class_name = "test_class_name"

      serialized_event_data = ListenerSerializer.dump(queue: queue, class_name: class_name)

      event_worker.perform(event_path, queue, class_name)

      Donaghy.redis.with do |redis|
        redis.sismember("donaghy_#{event_path}", serialized_event_data).should be_true
      end
    end

  end
end
