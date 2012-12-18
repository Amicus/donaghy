module Donaghy
  class SubscribeToEventWorker
    include Sidekiq::Worker
    sidekiq_options :queue => ROOT_QUEUE

    def perform(event_path, queue, class_name)
      logger.info("registering #{event_path} to #{queue}, #{class_name}")
      Donaghy.redis.with_connection do |redis|
        redis.multi do
          redis.sadd("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
          redis.zadd("donaghy_event_paths", 0, event_path)
        end
      end
    end

  end
end
