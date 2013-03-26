module Donaghy

  class EventDistributerWorker
    include Donaghy::Service

    donaghy_options = {:queue => ROOT_QUEUE}

    receives "donaghy/event_distributor", :handle_distribution

    def handle_distribution(path, event_hash)
      logger.info("received #{path}, #{event_hash.inspect}")

      QueueFinder.new(path).find.each do |queue_and_class|
        logger.info("sending to #{queue_and_class.inspect}")

        Donaghy.queue_for(queue_and_class[:queue]).publish(Event.from_hash(event_hash.merge(class: queue_and_class[:class])))
      end
    end

    def logger
      Donaghy.logger
    end

  end

end
