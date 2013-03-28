require 'celluloid/autostart'
require 'donaghy/middleware/chain'
require 'donaghy/middleware/stats'

module Donaghy
  class EventHandler
    include Celluloid
    include Logging

    def self.default_middleware
      Middleware::Chain.new do |c|
        c.add Middleware::Stats
      end
    end

    attr_reader :manager
    def initialize(manager)
      @manager = manager
    end

    def handle(event)
      logger.info("received: #{event.to_hash.inspect}")

      Donaghy.middleware.execute(current_actor, event) do
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
      end
      manager.async.event_handler_finished(current_actor)
    end

  end
end
