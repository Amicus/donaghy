require 'donaghy/listener_serializer'

module Donaghy
  class ListenerUpdater
    include Celluloid
    include Logging

    attr_reader :remote_storage, :local_storage
    def initialize(opts = {})
      @remote_storage = opts[:remote]
      @local_storage = opts[:local]
    end

    def update_local_event_paths
      event_paths = remote_storage.get('donaghy_event_paths')
      Array(event_paths).each do |event_path|
        local_storage.put("donaghy_remote#{event_path}", remote_storage.get("donaghy_#{event_path}"))
      end
      local_storage.put('donaghy_remoteevent_paths', event_paths)
    end

    def continuously_update_local_event_paths(interval)
      #update_local_event_paths
      every(interval) { update_local_event_paths }
    end

  end
end
