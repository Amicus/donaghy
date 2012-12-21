module Donaghy
  class UnsubscribeFromEventWorker
    include Sidekiq::Worker
    sidekiq_options :queue => ROOT_QUEUE

    def perform(event_path, queue, class_name)
      logger.warn("UNSUBSCRING #{event_path} from #{queue}, #{class_name}")
      Donaghy.redis.with do |redis|
        redis.multi do
          redis.srem("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
          redis.zrem("donaghy_event_paths", event_path)
        end
      end
    end

  end
end
