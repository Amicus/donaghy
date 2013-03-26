module Donaghy
  class SubscribeToEventWorker
    include Donaghy::Service
    donaghy_options  = {:queue => ROOT_QUEUE}

    EVENT_PATH = "donaghy/subscribe_to_path"

    receives EVENT_PATH, :handle_subscribe

    def self.async_subscribe(event_path, queue, class_name)
      Donaghy.root_queue.publish(Event.from_hash({
          path: "donaghy/subscribe_to_path",
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name
          }
      }))
    end

    def handle_subscribe(_, evt)
      payload = evt.payload
      event_path, queue, class_name = payload.event_path, payload.queue, payload.class_name
      subscribe_to_event(event_path, queue, class_name)
    end

    def subscribe_to_event(event_path, queue, class_name)
      logger.info("registering #{event_path} to #{queue}, #{class_name}")
      Donaghy.storage.add_to_set("donaghy_event_paths", event_path)
      Donaghy.storage.add_to_set("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
    end

  end
end
