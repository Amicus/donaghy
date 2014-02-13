require 'celluloid/autostart'
require "donaghy/sidekiq_runner"
require "donaghy/manager"
require 'donaghy/listener_updater'

module Donaghy
  class ClusterNode
    include Logging
    include Celluloid

    trap_exit :manager_died

    UPDATE_LOCAL_LISTENERS_EVERY = 20

    attr_reader :configuration, :cluster_manager, :local_manager,
                :listener_updater_supervisor
    def initialize(config = nil)
      @stop_requested = false
      @configuration = (config || Donaghy.configuration)
      @cluster_manager = Manager.new(name: "donaghy_cluster_#{configuration[:name]}", only_distribute: true, queue: Donaghy.root_queue, concurrency: configuration[:cluster_concurrency])
      @local_manager = Manager.new(name: configuration[:name].to_s, queue: Donaghy.default_queue, concurrency: configuration[:concurrency])
      @listener_updater_supervisor = ListenerUpdater.supervise(remote: Donaghy.storage, local: Donaghy.local_storage)
    end

    def start
      logger.debug('cluster node starting up')
      @stop_requested = false
      load_classes_and_subscribe_to_events
      logger.debug("starting cluster manager and local manager on #{Donaghy.default_queue.name}")
      futures = [
          @cluster_manager.future.start,
          @local_manager.future.start
      ]
      update_local_events
      every(UPDATE_LOCAL_LISTENERS_EVERY) do
        update_local_events
      end
      futures.each(&:value)
      logger.debug("cluster node started both cluster and local managers")
      signal(:started)
    end

    def blocking_start
      start
      wait(:stopped)
    end

    def handle_sidekiq_services
      logger.debug('subscribing to sidekiq services')
      SidekiqRunner.receives("#{Donaghy.root_event_path}/#{Service::SIDEKIQ_EVENT_PREFIX}.*", :handle_perform)
      SidekiqRunner.subscribe_to_global_events
    end

    def load_classes_and_subscribe_to_events
      logger.debug("subscribing to donaghy services and configured services: #{(donaghy_services + configured_services).inspect}")
      (donaghy_services + configured_services).each do |klass|
        klass.subscribe_to_global_events
      end
      handle_sidekiq_services
    end

    def donaghy_services
      [EventSubscriber, EventUnsubscriber]
    end

    def configured_services
      @services ||= Array(configuration[:services]).map do |service_name|
        const_name = service_name.camelize

        if Object.const_defined?(const_name)
          const_name.constantize
        else
          logger.warn("DEPRECATION WARNING: we no longer support auto loading of services... please require your classes first. For now, requiring #{service_name}")
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
      logger.info('stopping cluster node')
      @stop_requested = true
      listener_updater_supervisor.terminate if listener_updater_supervisor.alive?
      signal(:stop_requested)
      futures = [@cluster_manager, @local_manager].select(&:alive?).map do |manager|
        manager.future.stop(seconds)
      end

      Timeout.timeout(seconds + 10) do
        logger.info('waiting for managers to stop')
        futures.each do |future|
          future.value
        end
      end

      logger.debug('completely stopping cluster node with terminate')
      signal(:stopped)
      terminate
      true
    rescue Timeout::Error
      terminate
    end

    def update_local_events
      if listener_updater_supervisor.alive? and !@stop_requested
        listener_updater_supervisor.actors.first.update_local_event_paths
      end
    end

  end
end
