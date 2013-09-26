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
      if (path == "approvedReasons" || path == :approvedReasons)
        logger.warn("approved reasons recieved and event paths are #{event_paths}")
      end
      if event_paths and event_paths.respond_to?(:select)
        if (path == "approvedReasons" || path == :approvedReasons)
          logger.warn("Inside the first if block and about to match")
        end
        event_paths.select do |registered_path|
          if (path == "approvedReasons" || path == :approvedReasons)
            logger.warn("attempting to match with #{registered_path}")
          end
          File.fnmatch(registered_path, path)
        end
      else
        []
      end
    end

  end


end
