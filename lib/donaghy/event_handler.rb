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
      #TODO: actually do the work here
      event.acknowledge
      manager.async.event_handler_finished(current_actor)
    end

  end
end
