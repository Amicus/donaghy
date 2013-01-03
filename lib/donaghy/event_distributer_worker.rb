module Donaghy

  class EventDistributerWorker
    include Sidekiq::Worker

    sidekiq_options :queue => ROOT_QUEUE

    def perform(path, event_hash)
      logger.info("received #{path}, #{event_hash.inspect}")

      QueueFinder.new(path).find.each do |queue_and_class|
        logger.info("sending to #{queue_and_class.inspect}")
        Sidekiq::Client.push({
            'queue' => queue_and_class[:queue],
            'class' => queue_and_class[:class_name],
            'args' => [path, event_hash.to_hash]
        })
      end
    end

    def logger
      Sidekiq.logger
    end

  end

end
