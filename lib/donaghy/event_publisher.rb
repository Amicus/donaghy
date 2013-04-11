module Donaghy
  class EventPublisher
    include Donaghy::Service

    # overwrite the local trigger here because we never want /root/event_publisher/path
    # but we do want to default to including the root
    def trigger(path, opts = {})
      logger.info "#{self.class.name} is triggering: #{path_with_root(path)} with #{opts.inspect}"
      global_publish(path_with_root(path), opts)
    end

  end
end
