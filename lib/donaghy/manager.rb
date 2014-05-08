require 'celluloid/autostart'
require 'donaghy/fetcher'
require 'donaghy/event_handler'
require 'donaghy/remote_distributor'
require 'donaghy/manager_beater'

module Donaghy
  class Manager
    include Celluloid
    include Logging

    trap_exit :event_handler_died

    attr_reader :busy, :available, :fetcher, :stopped, :queue, :events_in_progress, :name, :only_distribute, :beater
    def initialize(opts = {})
      @name = opts[:name] || Celluloid::UUID.generate
      @only_distribute = opts[:only_distribute] || false
      @busy = []
      @events_in_progress = {}
      @concurrency = (opts[:concurrency] || opts['concurrency'] || Celluloid.cores)
      @available = @concurrency.times.map do
        new_event_handler
      end
      @beater = ManagerBeater.new(name)
      @queue = opts[:queue]
      @fetcher = new_fetcher
      @stopped = true
    end

    def start
      @stopped = false
      @beater.start_beating
      @available.length.times do
        assign_work
      end
      Donaghy.event_publisher.root_trigger("donaghy_cluster/manager.started", payload: {name: name, fqdn: Donaghy.hostname})
      true
    end

    def stop(seconds=0)
      @stopped = true
      logger.info("manager #{name} stopping the fetcher")
      fetcher.async.terminate if fetcher.alive?

      logger.info("manager #{name} terminating #{available.count} handlers")
      available.each do |handler|
        handler.async.terminate if handler.alive?
      end
      unless busy.empty?
        after(seconds) do
          logger.warn("manager #{name} shutting down #{busy.count} still busy handlers")
          busy.each do |busy_handler|
            events_in_progress[busy_handler.object_id].requeue
            busy_handler.async.terminate #give it a chance to cleanup
            Celluloid::Actor.kill(busy_handler) #but then nuke it
            remove_in_progress(busy_handler)
          end
          Donaghy.event_publisher.root_trigger("donaghy_cluster/manager.stopped", payload: {name: name, fqdn: Donaghy.hostname})
        end
      end
    ensure
      logger.info("manager #{name} stopping the beater")
      beater.async.terminate if beater.alive?
    end

    def stopped?
      @stopped
    end

  # private to the developer, but not to handlers, etc so can't use private here

    def new_fetcher
      Fetcher.new(current_actor, queue, {manager_name: name})
    end

    def new_event_handler
      EventHandler.new_link(current_actor, only_distribute: only_distribute)
    end

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
        event_handler.terminate if event_handler.alive?
      else
        if event_handler.alive?
          @available << event_handler
        else
          @available << new_event_handler
        end
        assign_work
      end
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
