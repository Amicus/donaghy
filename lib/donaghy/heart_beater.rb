module Donaghy
  class HeartBeater
    include Celluloid

    attr_reader :event, :timeout, :timer
    def initialize(event, timeout=10)
      @event = event
      @timeout = timeout
      @timer = nil
    end

    def stop
      unless timer.nil?
        timer.cancel
      end
      terminate
    end

    def beat
      event.heartbeat
      @timer = after(timeout) { beat }
      true
    end
  end
end
