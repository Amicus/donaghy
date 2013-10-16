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
        logger.info("NEUTERED #{manager_name} fetcher received evt #{evt.to_hash.inspect}, requeing because stopped")
        evt.requeue
      else
        if evt
          logger.info("NEUTERED #{manager_name} fetcher received evt #{evt.to_hash.inspect}")
          evt.received_on = queue
          queue_and_class_names = QueueFinder.new(evt.path, Donaghy.storage).find
          logger.info("NEUTERED #{manager_name} WOULD have sent this to #{queue_and_class_names.inspect}")
          evt.requeue
          #manager.async.handle_event(evt)
          sleep 10
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
