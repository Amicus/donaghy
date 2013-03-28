require "donaghy/sidekiq_runner"
require "donaghy/manager"

module Donaghy
  class ClusterNode
    include Logging
    include Celluloid

    trap_exit :manager_died

    attr_reader :configuration, :cluster_manager, :local_manager
    def initialize(config = nil)
      @configuration = (config || Donaghy.configuration)
      @cluster_manager = Manager.new(queue: Donaghy.root_queue, concurrency: configuration[:cluster_concurrency])
      @local_manager = Manager.new(queue: Donaghy.default_queue, concurrency: configuration[:cluster_concurrency])
    end

    def start
      load_classes_and_subscribe_to_events
      @cluster_manager.async.start
      @local_manager.async.start
      signal(:started)
    end

    def handle_sidekiq_services
      SidekiqRunner.receives("#{Donaghy.root_event_path}/#{Service::SIDEKIQ_EVENT_PREFIX}**/*", :handle_perform)
      SidekiqRunner.subscribe_to_global_events
    end

    def load_classes_and_subscribe_to_events
      handle_sidekiq_services
      (donaghy_services + configured_services).each do |klass|
        klass.subscribe_to_global_events
      end
      configured_services.each do |klass|
        klass.subscribe_to_pings
      end
    end

    def donaghy_services
      [EventSubscriber, EventUnsubscriber]
    end

    def configured_services
      @services ||= configuration[:services].map do |service_name|
        const_name = service_name.camelize

        if Object.const_defined?(const_name)
          const_name.constantize
        else
          logger.warn("DEPRECATION WARNING: we no longer support auto loading of services... please require your classes first")
          require "#{Dir.pwd}/lib/#{service_name}"
          const_name.constantize
        end
      end
    end

    def manager_died(manager, reason)
      logger.error("Manager: #{manager.inspect} died for reason: #{reason.class}")
      stop
    end

    def stop(seconds = 0)
      futures = [@cluster_manager, @local_manager].select(&:alive?).map do |manager|
        manager.future.stop(seconds)
      end

      configured_services.each do |klass|
        klass.unsubscribe_host_pings
      end

      futures.each do |future|
        future.value
      end
      terminate
      true
    end

  end
end
