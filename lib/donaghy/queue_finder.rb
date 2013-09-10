module Donaghy
  class QueueFinder
    include Logging

    attr_reader :path, :storage
    def initialize(path, storage)
      @path = path
      @storage = storage
    end

    def find
      matching_paths.map do |path|
        listeners_for(path)
      end.flatten
    end

    def listeners_for(matched_path)
      storage.get("donaghy_#{matched_path}").map do |serialized_listener|
        ListenerSerializer.load(serialized_listener)
      end
    end

    # we need to optimize this - but there ain't no event paths right now
    def matching_paths
      event_paths = storage.get("donaghy_event_paths")
      if event_paths and event_paths.respond_to?(:select)
        event_paths.select do |registered_path|
          File.fnmatch(registered_path, path)
          begin
            Regexp.new(registered_path) === path
          rescue RegexpError => e
            false
          end
        end
      else
        []
      end
    end

  end


end
