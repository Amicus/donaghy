module Donaghy
  class EventPublisher
    include Donaghy::Service

    def ping(root, service, reply_to, host = nil)
      if host
        event = Event.from_hash(payload: { reply_to: reply_to })
        Sidekiq::Client.push({
            'queue' => "donaghy_#{root}_#{host.gsub(/\./, '_')}",
            'class' => service,
            'args' => [ping_pattern(root, service), event.to_hash]
        })
      else
        root_trigger(ping_pattern(root, service), payload: { reply_to: reply_to })
      end
    end

    def ping_pattern(root, service)
      "#{root}/#{service.underscore}/ping"
    end


  end
end
