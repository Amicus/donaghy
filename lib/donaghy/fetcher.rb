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
      if evt
        evt.received_on = queue
        logger.info("received evt #{evt.to_hash.inspect}")
        if stopped? or !manager.alive?
          evt.requeue
        else
          manager.async.handle_event(evt)
        end
      else
        after(0) { fetch if current_actor.alive? } unless stopped?
      end
    end

    def stop_fetching
      @stopped = true
      terminate
    end

    def stopped?
      @stopped
    end

  end
end
