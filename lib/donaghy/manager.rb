require 'celluloid/autostart'
require 'donaghy/fetcher'
require 'donaghy/event_handler'

module Donaghy
  class Manager
    include Celluloid
    include Logging

    trap_exit :event_handler_died

    attr_reader :supervisor, :busy, :available, :fetcher, :stopped, :queue
    def initialize(opts = {})
      @busy = []
      @available = (opts[:concurrency] || opts['concurrency'] || Celluloid.cores).times.map do
        EventHandler.new_link(current_actor)
      end
      @queue = opts[:queue]
      @fetcher = Fetcher.new(current_actor, @queue)
    end

    def start
      @stopped = false
      @available.length.times do
        assign_work
      end
    end

    def stop
      @stopped = true
      fetcher.stop_fetching if fetcher.alive?
      # do more sidekiq like stuff here
      terminate
      signal(:shutdown)
    end

    def stopped?
      @stopped
    end

    def wait_for_shutdown
      wait(:shutdown)
    end


  # private to the developer, but not to handlers, etc so can't use private here

    def event_handler_or_fetcher_died(event_handler_or_fetcher, reason)
      logger.warn("handler or fetcher #{event_handler_or_fetcher.inspect} died do to #{reason.class}")
      @busy.delete(event_handler_or_fetcher)
      @available << EventHandler.new_link(current_actor)
    end

    def event_handler_finished(event_handler)
      @busy.delete(event_handler)
      if !event_handler.alive?
        @available << event_handler
      else
        @available << EventHandler.new_link(current_actor)
      end
    end

    def handle_event(evt)
      handler = @available.shift
      @busy << handler
      handler.async.handle(evt)
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