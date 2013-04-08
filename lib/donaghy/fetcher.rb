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
      evt = defer { queue.receive }
      if evt and !@stopped
        evt.received_on = queue
        logger.info("#{manager_name} fetcher received evt #{evt.to_hash.inspect}")
        manager.async.handle_event(evt)
      elsif evt and @stopped
        evt.received_on = queue
        logger.info("#{manager_name} fetcher received evt #{evt.to_hash.inspect}, requeing because stopped")
        evt.requeue
      else
        after(0) { fetch if !@stopped and manager.alive? } if !@stopped and manager.alive?
      end
    end

    def terminate
      logger.info("stop fetching received")
      @stopped = true
      super
    end

    def manager_name
      @manager_name ||= manager.name
    end

  end
end
