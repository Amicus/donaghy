module Donaghy

  class EventDistributerWorker
    include Donaghy::Service

    donaghy_options = {:queue => ROOT_QUEUE}

    receives "donaghy/event_distributor", :handle_distribution

    def handle_distribution(path, evt)
      logger.info("received #{path}, #{evt.to_hash.inspect}")

      QueueFinder.new(path).find.each do |queue_and_class|
        logger.info("sending to #{queue_and_class.inspect}")
        Donaghy.queue_for(queue_and_class[:queue]).publish(evt)
      end
    end

    def logger
      Donaghy.logger
    end

  end

end
