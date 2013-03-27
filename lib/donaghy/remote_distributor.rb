module Donaghy
  class RemoteDistributor
    include Logging

    def handle_distribution(evt)
      QueueFinder.new(evt.path, Donaghy.storage).find.each do |queue_and_class|
        logger.info("sending #{evt.path} to #{queue_and_class.inspect}")
        Donaghy.queue_for(queue_and_class[:queue]).publish(evt)
      end
    end
  end
end
