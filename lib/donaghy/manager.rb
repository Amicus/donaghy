require 'celluloid/autostart'
require 'donaghy/fetcher'
require 'donaghy/event_handler'
require "donaghy/remote_distributor"

module Donaghy
  class Manager
    include Celluloid
    include Logging

    class AskedToStop; end

    trap_exit :event_handler_died

    attr_reader :busy, :available, :fetcher, :stopped, :queue, :events_in_progress
    def initialize(opts = {})
      @busy = []
      @events_in_progress = {}
      @available = (opts[:concurrency] || opts['concurrency'] || Celluloid.cores).times.map do
        EventHandler.new_link(current_actor)
      end
      @queue = opts[:queue]
      @fetcher = Fetcher.new(current_actor, @queue)
      @stopped = true
    end

    def start
      @stopped = false
      @available.length.times do
        assign_work
      end
    end

    def stop(seconds = 0)
      @stopped = true
      logger.info("terminating #{available.count} handlers")
      async.internal_stop(seconds)
      if current_actor.alive?
        Timeout.timeout(seconds+1) do
          wait(:actually_stopped)
        end
      end
      terminate
      true
    end

    def internal_stop(seconds=0)
      fetcher.stop_fetching if fetcher.alive?

      available.each do |handler|
        handler.terminate if handler.alive?
      end
      if busy.empty?
        logger.debug("busy empty, signaling actually stopped")
        signal(:actually_stopped)
      else
        after(seconds) do
          logger.warn("shutting down #{busy.count} still active handlers")
          busy.each do |busy_handler|
            events_in_progress[busy_handler.object_id].requeue
            remove_in_progress(busy_handler)
            busy_handler.terminate
          end
          signal(:actually_stopped)
        end
      end
    end

    def stopped?
      @stopped
    end

  # private to the developer, but not to handlers, etc so can't use private here

    def event_handler_died(event_handler, reason)
      remove_in_progress(event_handler)
      @busy.delete(event_handler)
      unless stopped?
        @available << EventHandler.new_link(current_actor)
        assign_work
      end
    end

    def event_handler_finished(event_handler)
      @busy.delete(event_handler)
      remove_in_progress(event_handler)
      if stopped?
        event_handler.terminate
      elsif event_handler.alive?
        @available << event_handler
      else
        @available << EventHandler.new_link(current_actor)
      end
      assign_work unless stopped?
    end

    def handle_event(evt)
      if stopped?
        evt.requeue
      else
        event_handler = @available.shift
        @busy << event_handler
        events_in_progress[event_handler.object_id] = evt
        event_handler.async.handle(evt)
      end
    end

    def remove_in_progress(event_handler)
      events_in_progress.delete(event_handler.object_id)
    end

    def assign_work
      if fetcher.alive?
        fetcher.async.fetch
      else
        Fetcher.new(current_actor, @queue).async.fetch
      end
    end

  end
end
