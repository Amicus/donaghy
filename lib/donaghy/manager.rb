require 'celluloid/autostart'
require 'donaghy/fetcher'
require 'donaghy/event_handler'
require 'donaghy/remote_distributor'

module Donaghy
  class Manager
    include Celluloid
    include Logging

    class AskedToStop; end

    trap_exit :event_handler_died

    attr_reader :busy, :available, :fetcher, :stopped, :queue, :events_in_progress, :name, :only_distribute
    def initialize(opts = {})
      @name = opts[:name] || Celluloid::UUID.generate
      @only_distribute = opts[:only_distribute] || false
      @busy = []
      @events_in_progress = {}
      @available = (opts[:concurrency] || opts['concurrency'] || Celluloid.cores).times.map do
        new_event_handler
      end
      @queue = opts[:queue]
      @fetcher = new_fetcher
      @stopped = true
    end

    def start
      @stopped = false
      @available.length.times do
        assign_work
      end
      true
    end

    def new_fetcher
      Fetcher.new(current_actor, queue, manager_name: name)
    end

    def new_event_handler
      EventHandler.new_link(current_actor, only_distribute: only_distribute)
    end

    def stop(seconds = 0)
      logger.info("manager #{name} is being asked to stop in #{seconds} seconds")
      @stopped = true
      async.internal_stop(seconds)
      if current_actor.alive?
        Timeout.timeout(seconds+10) do
          wait(:actually_stopped)
        end
      end
      logger.info("manager #{name} received actually stopped so we are terminating")
      terminate
      true
    rescue Timeout::Error
      terminate
    end

    def internal_stop(seconds=0)
      logger.info("manager #{name} stopping the fetcher")
      fetcher.terminate if fetcher.alive?
      logger.info("manager #{name} terminating #{available.count} handlers")
      available.each do |handler|
        handler.terminate if handler.alive?
      end
      if busy.empty?
        logger.debug("manager #{name} busy empty, signaling actually stopped")
        signal(:actually_stopped)
      else
        after(seconds) do
          logger.warn("manager #{name} shutting down #{busy.count} still busy handlers")
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
      logger.warn("Event handler died due to #{reason.inspect}") if reason
      remove_in_progress(event_handler)
      @busy.delete(event_handler)
      unless stopped?
        @available << new_event_handler
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
        @available << new_event_handler
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
        @fetcher = new_fetcher
        @fetcher.async.fetch
      end
    end

  end
end
