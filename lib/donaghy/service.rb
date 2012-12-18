module Donaghy

  class UndefinedSystemError < StandardError; end

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
          Donaghy.logger.info "subscribing #{pattern} to #{[Donaghy.root_event_path, self.name]}"
          SubscribeToEventWorker.perform_async(pattern, Donaghy.root_event_path, self.name)
        end
      end

    end

    #sidekiq method distributor
    def perform(path, event_hash)
      receives_hash.each_pair do |pattern, meth_and_options|
        if File.fnmatch(pattern, path)
          send(meth_and_options[:method].to_sym, path, Event.from_hash(event_hash))
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

    def raise_system_error(evt, exception = nil)
      exception = exception || UndefinedSystemError.new
      logger.error("RAISE SYSTEM ERROR: #{evt}; #{exception.inspect}; #{exception.backtrace.join("\n")}")
      root_trigger("system_error", payload: {original_event: evt, exception: {
          klass: exception.class.to_s,
          backtrace: exception.backtrace.join("\n")
      }})
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
