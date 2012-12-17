module Donaghy
  class Server
    attr_reader :manager, :poller
    attr_accessor :queues
    def initialize(opts = {})
      @queues = opts[:queues] || []
      @queues << ROOT_QUEUE
    end

    def start
      configure_sidekiq

      Sidekiq::Stats::History.cleanup

      @manager = Sidekiq::Manager.new(sidekiq_options)
      @poller = Sidekiq::Scheduled::Poller.new
      manager.async.start
      poller.async.poll(true)
    end

    def stop
      poller.async.terminate if poller.alive?
      manager.async.stop(:shutdown => true, :timeout => sidekiq_options[:timeout])
      manager.wait(:shutdown)
    end

    def configure_sidekiq
      Sidekiq.configure_server do |config|
        config.redis = Donaghy.redis
      end

      Sidekiq.configure_client do |config|
        config.redis = Donaghy.redis
      end

      Sidekiq.options[:queues] += queues
    end

    def sidekiq_options
      Sidekiq.options
    end

  end
end
