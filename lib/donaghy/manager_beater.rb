module Donaghy
  class ManagerBeater
    include Celluloid

    attr_reader :name, :timeout, :timer, :stopped, :path_to_beat
    def initialize(name, timeout=10)
      @name = name
      @timeout = timeout
      @timer = nil
      @stopped = false
      @path_to_beat = "donaghy_#{Donaghy.hostname}_#{name}"
    end

    def terminate
      timer.cancel unless timer.nil?
      @stopped = true
      Donaghy.storage.remove_from_set("donaghy_#{Donaghy.hostname}", path_to_beat)
      Donaghy.storage.unset(path_to_beat)
      super
    end

    # add host to the donaghy_hosts and add the individual service to the hostname
    def start_beating
      Donaghy.storage.add_to_set('donaghy_hosts', Donaghy.hostname)
      Donaghy.storage.add_to_set("donaghy_#{Donaghy.hostname}", path_to_beat)
      beat
    end

  ### below should be private but can't because of the way the actor model works

    # store the configuration in the shared storage every so often, but let it expire, so when we stop beating
    # it will dissolve.
    def beat
      Donaghy.storage.put(path_to_beat, Donaghy.configuration.to_hash, timeout*3)
      @timer = after(timeout) { beat if !stopped and current_actor.alive? }
      true
    end
  end
end
