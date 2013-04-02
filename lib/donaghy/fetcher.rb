require 'celluloid/autostart'

module Donaghy
  class Fetcher
    include Celluloid
    include Logging

    attr_reader :manager, :queue
    def initialize(manager, queue, opts={})
      @manager = manager
      @queue = queue
    end

    def fetch
      logger.debug("fetch on #{queue.name}")
      evt = queue.receive
      if evt
        evt.received_on = queue
        logger.info("received evt #{evt.to_hash.inspect}")
        if stopped? or !manager.alive?
          evt.requeue
        else
          manager.async.handle_event(evt)
        end
      else
        after(0.5) { fetch if current_actor.alive? and !stopped? } unless stopped?
      end
    end

    def stop_fetching
      @stopped = true
      terminate
    end

    def stopped?
      @stopped || !manager.alive?
    end

  end
end
