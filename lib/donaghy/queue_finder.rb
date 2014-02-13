require 'active_support/core_ext/module/delegation'


module Donaghy
  class QueueFinder
    include Logging

    CACHE_UPDATE_INTERVAL = 30 #seconds

    attr_reader :path, :storage, :event, :guard, :prefix
    def initialize(path, storage, prefix=nil)
      @path = path
      @storage = storage
      @prefix = prefix
    end

    def find
      matching_paths.map do |path|
        listeners_for(path)
      end.flatten
    end

    def listeners_for(matched_path)
      listeners = nil
      listener_load_time = Benchmark.realtime do
        logger.info("about to fetch listeners on donaghy_#{matched_path} for event #{event.id if event} at time #{'%.6f' % Time.new.to_f}")
        listeners = storage.get("donaghy_#{prefix}#{matched_path}", event).map do |serialized_listener|
          ListenerSerializer.load(serialized_listener)
        end
      end
      logger.info("loading listeners took #{listener_load_time} on path #{matched_path} for event #{event.id unless event.nil?} at time #{'%.6f' % Time.new.to_f}")
      listeners
    end

    # we need to optimize this - but there ain't no event paths right now
    def matching_paths
      event_paths = nil
      event_paths_load_time = Benchmark.realtime do
        logger.info("about to fetch donaghy event paths for event #{event.id if event} at time #{'%.6f' % Time.new.to_f}")
        event_paths = storage.get("donaghy_#{prefix}event_paths", event)
      end
      logger.info("loading event paths took #{event_paths_load_time} for event #{event.id unless event.nil?} at time #{'%.6f' % Time.new.to_f}")
      logger.info("QueueFinder: event paths #{event_paths}")
      if event_paths and event_paths.respond_to?(:select)
        event_paths.select do |registered_path|
          if File.fnmatch(registered_path, path)
            true
          else
            begin
              Regexp.new(registered_path) === path
            rescue RegexpError => e
              logger.error("REGEXP error on #{registered_path}")
              false
            end
          end
        end
      else
        []
      end
    end

  end


end
