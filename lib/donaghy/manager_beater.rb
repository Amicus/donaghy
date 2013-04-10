module Donaghy
  class ManagerBeater
    include Celluloid

    attr_reader :name, :timeout, :timer, :stopped, :path_to_beat
    def initialize(name, timeout=10)
      @name = name
      @timeout = timeout
      @timer = nil
      @stopped = false
      @path_to_beat = "#{Donaghy.hostname}_#{name}"
    end

    def terminate
      timer.cancel unless timer.nil?
      @stopped = true
      super
    end

    # store the configuration in the shared storage every so often, but let it expire, so when we stop beating
    # it will dissolve.
    def beat
      Donaghy.storage.put(path_to_beat, Donaghy.configuration.to_hash, timeout*3)
      @timer = after(timeout) { beat if !stopped and current_actor.alive? }
      true
    end
  end
end
