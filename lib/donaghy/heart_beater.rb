module Donaghy
  class HeartBeater
    include Celluloid

    attr_reader :event, :timeout, :timer, :handler
    def initialize(event, handler, timeout=5)
      @handler = handler
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
      @timer = after(timeout) do
        if current_actor.alive? and handler.alive?
          beat
        elsif !handler.alive?
          terminate
        end
      end
      true
    end
  end
end
