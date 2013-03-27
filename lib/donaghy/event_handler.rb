require 'celluloid/autostart'

module Donaghy
  class EventHandler
    include Celluloid
    include Logging

    attr_reader :manager
    def initialize(manager)
      @manager = manager
    end

    def handle(event)
      logger.info("received: #{event.to_hash.inspect}")

      local_queues = QueueFinder.new(event.path, Donaghy.local_storage).find
      if local_queues.length > 0
        local_queues.each do |queue_and_class_name|
          class_name = queue_and_class_name[:class_name]
          class_name.constantize.new.distribute_event(event)
        end
      else
        logger.info("no local handler, so remote distributing")
        RemoteDistributor.new.handle_distribution(event)
      end

      event.acknowledge
      manager.async.event_handler_finished(current_actor)
    end

  end
end
