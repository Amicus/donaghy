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
      event_paths = Array(remote_storage.get(DONAGHY_EVENT_PATHS))

      event_paths.each do |event_path|
        local_storage.put("#{PATH_PREFIX}#{event_path}", remote_storage.get("#{PATH_PREFIX}#{event_path}"))
      end
      local_storage.put(DONAGHY_EVENT_PATHS, event_paths)
    end
  end
end
