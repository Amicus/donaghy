require 'socket'

module Donaghy
  class Server
    attr_reader :manager, :poller, :services
    attr_accessor :queues

    def name
      Donaghy.configuration[:name]
    end

    def start
      logger.info("starting server #{name}")
      setup_queues
      register_event_handlers
    end

    def stop
      logger.info("stopping server #{name}")
      poller.async.terminate if poller and poller.alive?
      unregister_host_ping_listeners
      if manager
        manager.async.stop(:shutdown => true, :timeout => sidekiq_options[:timeout])
        manager.wait(:shutdown)
      end
      Donaghy.shutdown_zk
    end

    def setup_queues
      logger.info('setting up queues')
      @queues ||= []
      @queues << ROOT_QUEUE
      @queues << Donaghy.local_service_host_queue
      @queues << Donaghy.configuration[:queue_name]
      logger.info("listening on #{queues.inspect}")
      @queues
    end

    def unregister_host_ping_listeners
      services.each do |service|
        service.unsubscribe_host_pings
      end
    end

    def register_event_handlers
      logger.info ("registering event handlers")
      services.each do |service|
        logger.info("registering pings for #{service.name}")
        service.subscribe_to_pings
        logger.info("registering global events for #{service.name}")
        service.subscribe_to_global_events
      end
    end

    def services
      @services ||= Donaghy.configuration[:services].map do |service_name|
        const_name = service_name.camelize

        if Object.const_defined?(const_name)
          const_name.constantize
        else
          require "#{Dir.pwd}/lib/#{service_name}"
          const_name.constantize
        end
      end
    end

    def service_versions
      services.each_with_object({}) do |service, hsh|
        version = service.const_defined?(:VERSION) ? service.const_get(:VERSION) : 'unkown'
        hsh[service.to_s] = version
      end
    end


    def logger
      Donaghy.logger
    end

  end
end
