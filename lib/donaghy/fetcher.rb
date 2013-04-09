require 'celluloid/autostart'

module Donaghy
  class Fetcher
    include Celluloid
    include Logging
    task_class TaskThread

    attr_reader :manager, :queue, :manager_name
    def initialize(manager, queue, opts={})
      @manager = manager
      @manager_name = opts[:manager_name]
      @queue = queue
    end

    def fetch
      evt = queue.receive
      if evt and !@stopped
        logger.info("#{manager_name} fetcher received evt #{evt.to_hash.inspect}")
        evt.received_on = queue
        manager.async.handle_event(evt)
      elsif evt and @stopped
        evt.received_on = queue
        logger.info("#{manager_name} fetcher received evt #{evt.to_hash.inspect}, requeing because stopped")
        evt.requeue
      else
        logger.info("redoing fetch of #{queue.name}")
        after(0) { fetch if !@stopped and manager.alive? } if !@stopped and manager.alive?
      end
    end

    def terminate
      logger.info("stop fetching received")
      @stopped = true
      super
    end

  end
end
