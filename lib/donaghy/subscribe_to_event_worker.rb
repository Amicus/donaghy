module Donaghy
  class SubscribeToEventWorker
    include Donaghy::Service
    donaghy_options  = {:queue => ROOT_QUEUE}

    receives "donaghy/subscribe_to_path", :handle_subscribe

    def handle_subscribe(path, evt)
      payload = evt.payload
      event_path, queue, class_name = payload.event_path, payload.queue, payload.class_name
      logger.info("registering #{event_path} to #{queue}, #{class_name}")
      Donaghy.storage.add_to_set("donaghy_event_paths", event_path)
      Donaghy.storage.put("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
    end

  end
end
