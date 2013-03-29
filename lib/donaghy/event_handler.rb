require 'celluloid/autostart'
require 'donaghy/heart_beater'
require 'donaghy/middleware/chain'
require 'donaghy/middleware/stats'
require 'donaghy/middleware/retry'
require 'donaghy/middleware/logging'

module Donaghy
  class EventHandler
    include Celluloid
    include Logging

    def self.default_middleware
      Middleware::Chain.new do |c|
        c.add Middleware::Retry
        c.add Middleware::Stats
        c.add Middleware::Logging
      end
    end

    attr_reader :manager, :uid
    def initialize(manager)
      @manager = manager
      @uid = Celluloid::UUID.generate
    end

    def handle(event)
      Donaghy.middleware.execute(current_actor, event) do
        local_queues = QueueFinder.new(event.path, Donaghy.local_storage).find
        if local_queues.length > 0
          local_queues.each do |queue_and_class_name|
            class_name = queue_and_class_name[:class_name]
            class_name.constantize.new.distribute_event(event)
          end
        else
          RemoteDistributor.new.handle_distribution(event)
        end
        event.acknowledge
      end
      manager.async.event_handler_finished(current_actor)
    end

  end
end
