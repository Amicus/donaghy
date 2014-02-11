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

    attr_reader :manager, :uid, :beat_timeout, :only_distribute
    attr_accessor :beater
    def initialize(manager, opts = {})
      @manager = manager
      @uid = "#{manager.name}_#{Celluloid::UUID.generate}"
      @beat_timeout = (opts[:heart_beat_timeout] || BEAT_TIMEOUT)
      @only_distribute = opts[:only_distribute]
    end

    def handle(event)
      self.beater = HeartBeater.new_link(event, current_actor, beat_timeout)
      beater.async.beat
      defer do
        Donaghy.middleware.execute(event, uid: uid, only_distribute: only_distribute, manager_name: manager.name) do
          if only_distribute
            if event.path.start_with?('donaghy/')
              logger.info("EventHandler #{uid} handling #{event.id}(#{event.path}) locally")
              handle_locally(event)
            else
              logger.info("EventHandler #{uid} is remote distributing #{event.id}(#{event.path})")
              RemoteDistributor.new.handle_distribution(event)
            end
          else
            logger.debug("EventHandler #{uid} handling #{event.id}(#{event.path}) locally")
            handle_locally(event)
          end
        end
      end
      logger.debug("EventHandler #{uid} completed #{event.id}(#{event.path}), acknowledging event")
      beater.terminate if beater.alive?
      event.acknowledge
      manager.async.event_handler_finished(current_actor)
    ensure
      beater.terminate if beater.alive?
      self.beater = nil
    end

    def handle_locally(event)
      local_queues = QueueFinder.new(event.path, Donaghy.local_storage).find
      if local_queues.empty?
        logger.error("EventHandler #{uid} received: #{event.id}(#{event.path}) but there are no local handlers")
      else
        local_queues.each do |queue_and_class_name|
          class_name = queue_and_class_name[:class_name]
          logger.debug("EventHandler #{uid} with path #{event.id}(#{event.path}) and is being sent to #{class_name}")
          class_name.constantize.new.distribute_event(event)
        end
      end
    end

    def terminate
      beater.terminate if beater and beater.alive?
      super
    end

  end
end
