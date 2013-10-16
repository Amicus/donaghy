require 'celluloid/autostart'

module Donaghy
  class Fetcher
    include Celluloid
    include Logging

    finalizer :cleanup

    attr_reader :manager, :queue, :manager_name
    def initialize(manager, queue, opts={})
      @manager = manager
      @manager_name = opts[:manager_name]
      @queue = queue
    end

    def fetch
      return if @stopped
      evt = queue.receive

      if done? and evt
        evt.received_on = queue
        logger.info("#{manager_name} fetcher received evt #{evt.path}, requeing because stopped")
        evt.requeue
      else
        if evt
          logger.info("#{manager_name} fetcher received evt #{evt.path}")
          evt.received_on = queue
          manager.async.handle_event(evt)
        else
          after(0) { fetch } unless done?
        end
      end
    end

    def done?
      !manager.alive? or @stopped
    end

    def cleanup
      @stopped = true
    end

  end
end
