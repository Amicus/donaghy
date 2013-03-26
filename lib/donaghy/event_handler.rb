require 'celluloid/autostart'

module Donaghy
  class EventHandler
    include Celluloid
    include Logging

    attr_reader :manager
    def initialize(manager)
      @manager = manager
    end

    def process(event)
      logger.info("received: #{event.to_hash.inspect}")
      event.acknowledge
      manager.async.event_handler_finished(current_actor)
    end

  end
end
