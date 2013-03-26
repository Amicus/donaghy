require 'socket'
require 'active_support/core_ext/class/attribute'

module Donaghy

  class UndefinedSystemError < StandardError; end

  module Service

    def self.included(klass)
      klass.class_attribute :donaghy_options
      klass.class_attribute :internal_root_path
      klass.extend(ClassMethods)
      klass.donaghy_options  = {queue: Donaghy.root_event_path}
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
          Donaghy.logger.info "subscribing #{pattern} to #{[Donaghy.root_event_path, self.name]}"
          global_publish
          SubscribeToEventWorker.perform_async(pattern, Donaghy.root_event_path, self.name)
        end
      end

      def subscribe_to_pings
        SubscribeToEventWorker.perform_async(ping_pattern, Donaghy.root_event_path, self.name)
        SubscribeToEventWorker.perform_async(ping_pattern, Donaghy.local_service_host_queue, self.name)
      end

      def unsubscribe_host_pings
        UnsubscribeFromEventWorker.perform_async(ping_pattern, Donaghy.local_service_host_queue, self.name)
      end

      #this is for shutting down a service for good
      def unsubscribe_all_instances
        receives_hash.each_pair do |pattern, meth_and_options|
          Donaghy.logger.warn "unsubscribing all instances of #{to_s} from #{[Donaghy.root_event_path, self.name]}"
          UnsubscribeFromEventWorker.perform_async(pattern, Donaghy.root_event_path, self.name)
          [Donaghy.root_event_path, Donaghy.local_service_host_queue].each do |queue|
            UnsubscribeFromEventWorker.perform_async(ping_pattern, queue, self.name)
          end
        end
      end

      def service_version
        const_defined?(:VERSION) ? const_get(:VERSION) : "unkown"
      end

      def ping_pattern
        "#{Donaghy.configuration[:name]}/#{self.name.underscore}/ping*"
      end

    end

    #sidekiq method distributor
    def perform(path, event_hash)
      if path == self.class.redis_ping_pattern
        redis_ping(path, Event.from_hash(event_hash))
      elsif File.fnmatch(self.class.ping_pattern, path)
        donaghy_ping(path, Event.from_hash(event_hash))
      else
        receives_hash.each_pair do |pattern, meth_and_options|
          if File.fnmatch(pattern, path)
            send(meth_and_options[:method].to_sym, path, Event.from_hash(event_hash))
          end
        end
      end
    end

    def receives_hash
      self.class.receives_hash
    end

    def trigger(path, opts = {})
      logger.info "#{self.class.name} is triggering: #{event_path(path)} with #{opts.inspect}"
      global_publish(event_path(path), opts)
    end

    def root_trigger(path, opts = {})
      logger.info "#{self.class.name} is global_root_triggering: #{path} with #{opts.inspect}"
      global_publish(path, opts)
    end

    def raise_system_error(message, evt = nil, exception = nil)
      exception = exception || UndefinedSystemError.new(message)
      backtrace = exception.backtrace ? exception.backtrace.join("\n") : ""
      logger.error("RAISE SYSTEM ERROR: #{message}, original_event: #{evt.inspect}; exception: #{exception.inspect}; #{backtrace}")
      root_trigger("system_error", payload: {original_event: evt, exception: {
          klass: exception.class.to_s,
          backtrace: backtrace
      }})
    end

    def donaghy_ping(path, evt)
      reply_event = evt.payload['reply_to']
      logger.debug("PING RECEIVED: #{path}, REPLY_TO: #{reply_event}")
      root_trigger(reply_event, payload: {
          id: evt.payload['id'],
          received_at: Time.now.utc,
          version: self.class.service_version,
          configuration: Donaghy.configuration.to_hash
      })
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
