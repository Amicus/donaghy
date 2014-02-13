require 'active_support/core_ext/module/delegation'


module Donaghy
  class QueueFinder
    include Logging

    attr_reader :event_path, :storage, :local
    def initialize(event_path, storage, opts = {})
      @event_path = event_path
      @storage = storage
      @local = opts[:local]
    end

    def find
      matching_paths.map do |path|
        listeners_for(path)
      end.flatten
    end

    def listeners_for(matched_path)
      storage.get(storage_path_from_path(matched_path)).map do |serialized_listener|
        ListenerSerializer.load(serialized_listener)
      end
    end

    def matching_paths
      Array(storage.get(event_paths_path)).select { |registered_path| path_matches?(registered_path) }
    end

  private
    def path_matches?(registered_path)
      if File.fnmatch(registered_path, event_path)
        true
      else
        begin
          Regexp.new(registered_path) === event_path
        rescue RegexpError => e
          logger.error("REGEXP error on '#{registered_path}', #{e.inspect}")
          false
        end
      end
    end

    def local?
      @local
    end

    def event_paths_path
      local? ? LOCAL_DONAGHY_EVENT_PATHS : DONAGHY_EVENT_PATHS
    end

    def storage_path_from_path(path)
      local? ? "#{LOCAL_PATH_PREFIX}#{path}" : "#{PATH_PREFIX}#{path}"
    end

  end


end
