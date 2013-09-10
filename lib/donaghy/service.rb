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
        #nested hash of top_level_event -> actions -> handler
        action = opts[:action] || "all"
        receives_hash[pattern] = {} unless receives_hash.include?(pattern)
        receives_hash[pattern][action] = {method: meth, options: opts}
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
        receives_hash.each_pair do |pattern, actions|
          Donaghy.logger.info "subscribing #{pattern} to #{[Donaghy.default_queue_name, self.name]}"
          EventSubscriber.new.subscribe(pattern, Donaghy.default_queue_name, self.name)
        end
      end

      #this is for shutting down a service for good
      def unsubscribe_all_instances
        receives_hash.each_pair do |pattern, actions|
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
      action_of_event = event.dimensions[:action] if event.dimensions
      event_path = event.path

      receives_hash.each_pair do |saved_pattern, actions|
        if is_pattern_match?(event_path, saved_pattern)
          fire_all_handler(event_path, action_of_event, saved_pattern, event)
          if method_name = method_for_action(actions, action_of_event)
            send(method_name, event)
          end
        end
      end
    end

    def fire_all_handler(event_path, event_action, saved_pattern, event)
      send(receives_hash[saved_pattern]["all"][:method].to_sym, event) if receives_hash[saved_pattern].include?("all")
    end

    def is_pattern_match?(event_path, path_listening_to)
      event_path === path_listening_to || Regexp.new(path_listening_to) === event_path
    end

    def method_for_action(actions, event_action)
      meth_and_options = actions[event_action] if event_action != nil
      if meth_and_options
        meth_and_options[:method].to_sym
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
