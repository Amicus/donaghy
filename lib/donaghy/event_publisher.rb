module Donaghy
  class EventPublisher
    include Donaghy::Service

    # overwrite the local trigger here because we never want /root/event_publisher/path
    # but we do want to default to including the root
    def trigger(path, opts = {})
      logger.info "#{self.class.name} is triggering: #{path_with_root(path)} with #{opts.inspect}"
      global_publish(path_with_root(path), opts)
    end

    #opts takes host and id
    def ping(root, service, reply_to, opts = {})
      host = opts[:host]
      ping_pattern = opts[:redis] ? redis_ping_pattern(root, service) : evented_ping_pattern(root, service)

      if host
        event = Event.from_hash(payload: { reply_to: reply_to, id: opts[:id] })
        Sidekiq::Client.push({
            'queue' => "donaghy_#{root}_#{host.gsub(/\./, '_')}",
            'class' => service,
            'args' => [ping_pattern, event.to_hash]
        })
      else
        root_trigger(ping_pattern, payload: { reply_to: reply_to, id: opts[:id] })
      end
    end

    def evented_ping_pattern(root, service)
      "#{root}/#{service.underscore}/ping"
    end

    def redis_ping_pattern(root, service)
      "#{root}/#{service.underscore}/ping/redis"
    end

    # create a random key that will expire if not returned
    # then use the redis ping and block on popping off the queue
    def blocking_ping(root, service, opts = {})
      random_queue = "#{root}_#{service.underscore}_#{SecureRandom.base64(16)}"
      timeout_in = opts[:timeout] || 5
      Timeout.timeout(timeout_in) do
        ping(root, service, random_queue, opts.merge(redis: true))
        queue, event = Donaghy.redis.with do |conn|
          conn.pexpire(random_queue, (timeout_in + 1)*1000)
          conn.blpop(random_queue)
        end
        Event.from_hash(JSON.load(event))
      end
    end


  end
end
