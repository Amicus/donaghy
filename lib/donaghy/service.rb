module Donaghy

  module Service

    def self.included(klass)
      klass.send(:include, Sidekiq::Worker)
      klass.class_attribute :internal_root_path
      klass.extend(ClassMethods)
      klass.sidekiq_options queue: Donaghy.root_event_path
    end

    module ClassMethods
      def receives_hash
        @receives_hash ||= {}
      end

      def receives(pattern, meth, opts = {})
        receives_hash[pattern] = {method: meth, options: opts}
      end

      def subscribe_to_global_events
        receives_hash.each_pair do |pattern, meth_and_options|
          SubscribeToEventWorker.perform_async(pattern, Donaghy.root_event_path, self.name)
        end
      end

    end

    #sidekiq method distributor
    def perform(path, event_hash)
      meth_and_options = receives_hash[path]
      send(meth_and_options[:method].to_sym, path, Event.from_hash(event_hash))
    end

    def receives_hash
      self.class.receives_hash
    end

    def trigger(path, opts = {})
      logger.debug "#{self.class.name} is triggering: #{event_path(path)} with #{opts.inspect}"
      global_publish(event_path(path), opts)
    end

    def root_trigger(path, opts = {})
      logger.debug "#{self.class.name} is global_root_triggering: #{path_with_root(path)} with #{opts.inspect}"
      global_publish(path_with_root(path), opts)
    end

  private

    def global_publish(path, opts = {})
      Donaghy::EventDistributerWorker.perform_async(path, event_from_options(path, opts).to_hash)
    end

    def event_from_options(path, opts)
      generated_by = Array(opts[:generated_by]).dup
      generated_by.unshift(path)
      Event.from_hash(path: path, payload: opts[:payload], generated_by: generated_by, target: self)
    end

    def event_path(path)
      logger.debug("event path for #{path} on #{self}")
      if internal_root
        path = "#{internal_root}/#{path}"
      end
      if root_event_path
        path = "#{root_event_path}/#{path}"
      end
      path
    end

    def path_with_root(path)
      if root_event_path
        path = "#{root_event_path}/#{path}"
      end
      path
    end

    def internal_root
      self.class.internal_root_path || File.basename(self.class.name.underscore)
    end

    def logger
      Donaghy.logger
    end

    def root_event_path
      Donaghy.root_event_path
    end
  end

end
