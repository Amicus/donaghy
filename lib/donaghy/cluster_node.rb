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
      logger.info('ClusterNode starting up')
      @stop_requested = false
      load_classes_and_subscribe_to_events
      logger.debug("ClusterNode starting cluster manager and local manager on #{Donaghy.default_queue.name}")
      futures = [
          @cluster_manager.future.start,
          @local_manager.future.start
      ]
      update_local_events
      every(UPDATE_LOCAL_LISTENERS_EVERY) do
        update_local_events
      end
      futures.each(&:value)
      logger.info("ClusterNode started both cluster and local managers")
      signal(:started)
    end

    def blocking_start
      start
      wait(:stopped)
    end

    def handle_sidekiq_services
      logger.debug('ClusterNode subscribing to sidekiq services')
      SidekiqRunner.receives("#{Donaghy.root_event_path}/#{Service::SIDEKIQ_EVENT_PREFIX}.*", :handle_perform)
      SidekiqRunner.subscribe_to_global_events
    end

    def load_classes_and_subscribe_to_events
      logger.debug("ClusterNode subscribing to donaghy services and configured services: #{(donaghy_services + configured_services).inspect}")
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
      @stop_requested = true
      logger.info('ClusterNode stopping')

      listener_updater_supervisor.async.terminate if listener_updater_supervisor.alive?
      futures = [@local_manager, @cluster_manager].select(&:alive?).map do |manager|
        logger.info("ClusterNode stopping #{manager.name}")
        manager.future.stop(seconds)
      end

      timeout(seconds + 10) do
        logger.info('ClusterNode waiting for managers to stop')
        futures.each do |future|
          begin
            future.value
          rescue Celluloid::Task::TerminatedError # we don't care if the job was already terminated
          rescue Celluloid::DeadActorError # also don't care if that actor is already dead
          rescue Task::TimeoutError
            logger.error("ClusterNode Timeout error from manager stop")
          end
        end
      end

      logger.info('ClusterNode stopped')
      signal(:stopped)
      terminate if current_actor.alive?
      true
    rescue Task::TimeoutError
      logger.error("ClusterNode timeout error from double manager shutdown")
      terminate if current_actor.alive?
    end

    def update_local_events
      if listener_updater_supervisor.alive? and !@stop_requested and current_actor.alive?
        actor = listener_updater_supervisor.actors.first
        actor.async.update_local_event_paths if actor.alive?
      end
    end

  end
end
