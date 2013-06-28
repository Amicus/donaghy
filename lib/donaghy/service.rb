require 'active_support/core_ext/class/attribute'

module Donaghy

  module Service
    SIDEKIQ_EVENT_PREFIX = "donaghy/sidekiq_emulator/"

    def self.included(klass)
      klass.class_attribute :donaghy_options
      klass.class_attribute :internal_root_path
      klass.extend(ClassMethods)
    end

    module ClassMethods
      ##### public Class API

      def receives(pattern, meth, opts = {})
        receives_hash[pattern] = {method: meth, options: opts}
      end

      def perform_async(*args)
        instance = new()
        instance.perform_async(*args)
      end

      def service_version
        const_defined?(:VERSION) ? const_get(:VERSION) : "unkown"
      end

      #### private (but can't be private because donaghy internals call these methods)

      def receives_hash
        @receives_hash ||= {}
      end

      def subscribe_to_global_events
        receives_hash.each_pair do |pattern, meth_and_options|
          Donaghy.logger.info "subscribing #{pattern} to #{[Donaghy.default_queue_name, self.name]}"
          EventSubscriber.new.subscribe(pattern, Donaghy.default_queue_name, self.name)
        end
      end

      #this is for shutting down a service for good
      def unsubscribe_all_instances
        receives_hash.each_pair do |pattern, meth_and_options|
          Donaghy.logger.warn "unsubscribing all instances of #{to_s} from #{[Donaghy.default_queue_name, self.name]}"
          EventUnsubscriber.new.unsubscribe(pattern, Donaghy.default_queue_name, self.name)
        end
      end
    end

    ### Public Instance API
    def trigger(path, opts = {})
      logger.info "#{self.class.name} is triggering: #{event_path(path)} with #{opts.inspect}"
      global_publish(event_path(path), opts)
    end

    def root_trigger(path, opts = {})
      logger.info "#{self.class.name} is global_root_triggering: #{path} with #{opts.inspect}"
      global_publish(path, opts)
    end

    ### private instance api (but can't be private because internals use these)

    def distribute_event(event)
      puts event.to_s + " distribute_event testingg"
      receives_hash.each_pair do |pattern, meth_and_options|
        if File.fnmatch(pattern, event.path)
          meth = method(meth_and_options[:method].to_sym)
          # this is in here to support path, event which is unnecessary if you're just sending events around
          # as they have a path method
          if meth.arity == 1
            send(meth_and_options[:method].to_sym, event)
          else
            logger.warn("DEPRECATION WARNING: #{meth_and_options[:method]} on #{self.class.to_s} still takes (path, event) when it should only take (event)")
            send(meth_and_options[:method].to_sym, event.path, event)
          end
        end
      end
    end

    def perform_async(*args)
      root_trigger(sidekiq_emulator_path, payload: {args: args})
    end

  private

    def receives_hash
      self.class.receives_hash
    end

    def sidekiq_emulator_path
      "#{Donaghy.root_event_path}/#{SIDEKIQ_EVENT_PREFIX}#{self.class.to_s.underscore}"
    end

    def global_publish(path, opts = {})
      Donaghy.root_queue.publish(event_from_options(path, opts))
    end

    def event_from_options(path, opts)
      puts opts.to_s + " event_from_options testingg "
      generated_by = Array(opts[:generated_by]).dup
      generated_by.unshift(path)
      Event.from_hash(opts.merge(path: path, generated_by: generated_by))
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
