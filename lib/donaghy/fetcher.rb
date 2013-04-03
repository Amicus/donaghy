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
      evt = queue.receive
      if evt and !stopped?
        evt.received_on = queue
        logger.info("received evt #{evt.to_hash.inspect}")
        manager.async.handle_event(evt)
      elsif evt and stopped?
        evt.received_on = queue
        logger.info("received evt #{evt.to_hash.inspect}, requeing because stopped")
        evt.requeue
      else
        after(0) { fetch if current_actor.alive? and !stopped? } unless stopped?
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
