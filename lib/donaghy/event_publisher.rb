module Donaghy
  class EventPublisher
    include Donaghy::Service

    class LowPriorityPublisher
      include Donaghy::Service
      include Celluloid
    end
    
    attr_reader :supervisor
    def initialize
      @supervisor = LowPriorityPublisher.supervise
    end

    def low_priority_trigger(path, opts = {})
      actor.async.root_trigger(path, opts)
    end

    def stop
      supervisor.terminate if supervisor.alive?
    end

    def alive?
      supervisor.alive?
    end

  private
    def actor
      supervisor.actors.first
    end

  end
end
