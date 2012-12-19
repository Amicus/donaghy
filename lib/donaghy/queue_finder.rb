module Donaghy
  class QueueFinder

    def initialize(path)
      @path = path
    end

    def find
      matching_paths.map do |path|
        listeners_for(path)
      end.flatten
    end

    def listeners_for(matched_path)
      redis.with do |redis|
        redis.smembers("donaghy_#{matched_path}").map do |serialized_listener|
          ListenerSerializer.load(serialized_listener)
        end
      end
    end

    # we need to optimize this - but there ain't no event paths right now
    def matching_paths
      redis.with do |redis|
        redis.zrange("donaghy_event_paths", 0, -1).select do |registered_path|
          File.fnmatch(registered_path, @path)
        end
      end
    end

    def redis
      Donaghy.redis
    end

  end


end
