module Donaghy
  class HeartBeater
    include Celluloid

    finalizer :cleanup

    attr_reader :event, :timeout, :timer, :handler
    def initialize(event, handler, timeout=5)
      @handler = handler
      @event = event
      @timeout = timeout
      @timer = nil
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

    def cleanup
      timer.cancel unless timer.nil?
    end
  end
end
