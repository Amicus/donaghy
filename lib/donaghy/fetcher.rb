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
        logger.info("received evt #{evt.to_hash.inspect}")
        @manager.async.handle_event(evt)
      else
        after(0) { fetch } unless @done
      end
    end

    def stop_fetching
      @done = true
      terminate
    end

  end
end
