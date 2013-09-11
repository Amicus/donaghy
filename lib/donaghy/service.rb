require 'active_support/core_ext/class/attribute'

module Donaghy

  module Service
    SIDEKIQ_EVENT_PREFIX = "donaghy/sidekiq_emulator/"

    class CalledTriggerError < StandardError; end

    def self.included(klass)
      klass.class_attribute :donaghy_options
      klass.class_attribute :internal_root_path
      klass.extend(ClassMethods)
    end

    module ClassMethods
      ##### public Class API

      def receives(pattern, meth, opts = {})
        #nested hash of top_level_event -> actions -> handler
        action = opts[:action] || :all
        action = action.to_sym
        receives_hash[pattern] = {} unless receives_hash.include?(pattern)
        receives_hash[pattern][action] = {method: meth, options: opts}
        cache_regexp!(pattern)
      end

      def cache_regexp!(pattern)
        if !receives_hash[pattern][:regexp]
          begin
            receives_hash[pattern][:regexp] = Regexp.new(pattern)
          rescue
            receives_hash[pattern][:regexp] = :invalid_regexp
          end
        end
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
    def root_trigger(path, opts = {})
      logger.info "#{self.class.name} is triggering: #{path} with #{opts.inspect}"
      global_publish(path, opts)
    end

    def trigger(path, opts = {})
      raise CalledTriggerError
    end

    ### private instance api (but can't be private because internals use these)
    def distribute_event(event)
      action_of_event = event.payload.dimensions[:action] if event.payload && event.payload[:dimensions]
      event_path = event.path #add parity of method back in for backwards compatiability

      receives_hash.each_pair do |saved_pattern, actions|
        if is_match?(event_path, saved_pattern)
          fire_all_handler(event_path, action_of_event, saved_pattern, event)
          if method_name = method_for_action(actions, action_of_event)
            fire_handler!(method_name, event)
          end
        end
      end
    end

    def fire_handler!(method_name, event)
      #this is here to support deprecated handlers of type method_name(path, event)
      meth = method(method_name)
      if meth.arity == 1
        send(method_name, event)
      else
        logger.warn("DEPRECATION WARNING: #{method_name} on #{self.class.to_s} still takes (path, event) when it should only take (event)")
        send(method_name, event.path, event)
      end
    end

    def fire_all_handler(event_path, event_action, saved_pattern, event)
      if receives_hash[saved_pattern].include?(:all)
        fire_handler!(receives_hash[saved_pattern][:all][:method].to_sym, event)
      end
    end

    def is_match?(event_path, path_listening_to)
      if File.fnmatch(path_listening_to, event_path)
        true
      else
        pattern_regexp = receives_hash[path_listening_to][:regexp]
        pattern_regexp === event_path unless pattern_regexp == :invalid_regexp
      end
    end

    def method_for_action(actions, event_action)
      meth_and_options = actions[event_action.to_sym] if event_action != nil
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
      ensure_payload!(opts)
      add_event_origin!(path, opts[:payload], opts)
      generated_by = Array(opts[:generated_by]).dup
      generated_by.unshift(path)
      Event.from_hash(opts.merge(path: path, generated_by: generated_by))
    end

    def add_event_origin!(path, payload, opts)
      dimensions = payload[:dimensions] || {}
      dimensions.merge!({
          deprecated_path: event_path(path),
          file_origin: internal_root,
          application_origin: root_event_path
        })
      opts[:payload][:dimensions] = dimensions
    end

    def ensure_payload!(opts)
      if !opts[:payload]
        opts.merge!({
          payload: {}
          })
      elsif !opts[:payload].kind_of?(Hash)
        opts[:payload] = Hashie::Mash.new(:value => opts[:payload])
      end

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
