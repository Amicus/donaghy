module Donaghy
  class QueueFinder

    def self.all_listeners
      all_paths = Donaghy.storage.get("donaghy_event_paths")
      listeners_array = all_paths.map do |path|
        Donaghy.storage.get("donaghy_#{path}").map {|serialized_listener| ListenerSerializer.load(serialized_listener)}
      end
      Hash[all_paths.zip(listeners_array)]
    end

    def initialize(path)
      @path = path
    end

    def find
      matching_paths.map do |path|
        listeners_for(path)
      end.flatten
    end

    def listeners_for(matched_path)
      Donaghy.storage.get("donaghy_#{matched_path}").map do |serialized_listener|
        ListenerSerializer.load(serialized_listener)
      end
    end

    # we need to optimize this - but there ain't no event paths right now
    def matching_paths
      Donaghy.storage.get("donaghy_event_paths").select do |registered_path|
        File.fnmatch(registered_path, @path)
      end
    end

  end


end
