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
      configure_sidekiq
      Sidekiq::Stats::History.cleanup
      start_sidekiq
    end

    def stop
      logger.info("stopping server #{name}")
      poller.async.terminate if poller and poller.alive?
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
      @queues << Donaghy.configuration[:queue_name]
      logger.info("listening on #{queues.inspect}")
      @queues
    end

    def register_event_handlers
      logger.info ("registering event handlers")
      services.each do |service|
        logger.info("registering global events for #{service.name}")
        service.subscribe_to_global_events
      end
    end

    def services
      Donaghy.configuration[:services].map do |service_name|
        const_name = service_name.camelize

        if Object.const_defined?(const_name)
          const_name.constantize
        else
          require "lib/#{service_name}"
          const_name.constantize
        end
      end
    end

    def start_sidekiq
      logger.info('starting sidekiq')
      @manager = Sidekiq::Manager.new(sidekiq_options)
      @poller = Sidekiq::Scheduled::Poller.new
      manager.async.start
      poller.async.poll(true)
      Thread.pass
    end

    def configure_sidekiq
      Sidekiq.configure_server do |config|
        config.redis = Donaghy.redis
      end

      Sidekiq.configure_client do |config|
        config.redis = Donaghy.redis
      end

      Sidekiq.logger = Donaghy.logger
      Sidekiq.options[:concurrency] = Donaghy.configuration[:concurrency] || 25

      Sidekiq.options[:queues] += queues
    end

    def sidekiq_options
      Sidekiq.options
    end

    def logger
      Donaghy.logger
    end

  end
end
