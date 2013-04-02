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

    BEAT_TIMEOUT = 5

    attr_reader :manager, :uid, :beat_timeout
    attr_accessor :beater
    def initialize(manager, opts = {})
      @manager = manager
      @uid = Celluloid::UUID.generate
      @beat_timeout = (opts[:heart_beat_timeout] || BEAT_TIMEOUT)
    end

    def handle(event)
      self.beater = HeartBeater.new_link(event, beat_timeout)
      beater.async.beat
      logger.debug("#{uid} is handling event")

      Donaghy.middleware.execute(current_actor, event) do
        local_queues = QueueFinder.new(event.path, Donaghy.local_storage).find
        if local_queues.length > 0
          local_queues.each do |queue_and_class_name|
            class_name = queue_and_class_name[:class_name]
            class_name.constantize.new.distribute_event(event)
          end
        else
          logger.debug("#{uid} could not find local class to handle this event so remote distributing")
          RemoteDistributor.new.handle_distribution(event)
        end
        logger.debug("#{uid} complete, acknowledging event")
        beater.terminate if beater.alive?
        event.acknowledge
      end
      manager.async.event_handler_finished(current_actor)
    ensure
      beater.terminate if beater.alive?
      self.beater = nil
    end

    def terminate
      beater.terminate if beater and beater.alive?
      super
    end

  end
end
