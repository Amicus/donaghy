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
      configure_sidekiq
      register_event_handlers
      Sidekiq::Stats::History.cleanup
      register_in_zk
      start_sidekiq
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

    def register_in_zk
      zk_base_path = "/donaghy/#{name}"
      zk.mkdir_p(zk_base_path)
      zk_create_or_set("#{zk_base_path}/#{Socket.gethostname}", Marshal.dump({
                donaghy_configuration: Donaghy.configuration.to_hash,
                service_versions: service_versions
      }))
    end

    def service_versions
      services.each_with_object({}) do |service, hsh|
        version = service.const_defined?(:VERSION) ? service.const_get(:VERSION) : 'unkown'
        hsh[service.to_s] = version
      end
    end

    def zk_create_or_set(path, data)
      zk.create(path, data, mode: :ephemeral)
    rescue ZK::Exceptions::NodeExists
      logger.warn("Trying to create the ephemeral node for #{path} but it already existed")
      zk.set(path, data)
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

      Sidekiq.options[:queues] = (Sidekiq.options[:queues] + queues).uniq
    end

    def sidekiq_options
      Sidekiq.options
    end

    def zk
      Donaghy.zk
    end

    def logger
      Donaghy.logger
    end

  end
end
