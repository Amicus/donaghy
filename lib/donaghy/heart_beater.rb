module Donaghy
  class HeartBeater
    include Celluloid

    attr_reader :event, :timeout, :timer
    def initialize(event, timeout=5)
      @event = event
      @timeout = timeout
      @timer = nil
    end

    def terminate
      stop_beating
      super
    end

    def stop_beating
      unless timer.nil?
        timer.cancel
      end
    end

    def beat
      event.heartbeat(timeout*3) #we multiply by 3 to account for errors
      @timer = after(timeout) { beat if current_actor.alive? }
      true
    end
  end
end
