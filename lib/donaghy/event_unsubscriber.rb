module Donaghy
  class EventUnsubscriber
    include Donaghy::Service
    donaghy_options = {:queue => ROOT_QUEUE}

    EVENT_PATH = "donaghy/unsubscribe_from_path"
    receives EVENT_PATH, :handle_unsubscribe

    def unsubscribe(event_path, queue, class_name)
      global_unsubscribe(event_path, queue, class_name)
      local_unsubscribe(event_path, queue, class_name)
    end

    def local_unsubscribe(event_path, queue, class_name)
      logger.info("local unsubscribing #{event_path} from #{queue} and #{class_name}")
      Donaghy.local_storage.remove_from_set("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
      Donaghy.local_storage.remove_from_set("donaghy_event_paths", event_path)
    end

    def global_unsubscribe(event_path, queue, class_name)
      Donaghy.root_queue.publish(Event.from_hash({
          path: EVENT_PATH,
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name
          }
      }))
    end

    def handle_unsubscribe(evt)
      payload = evt.payload
      event_path, queue, class_name = payload.event_path, payload.queue, payload.class_name
      logger.info("globally unsubscribing #{event_path} from #{queue}, #{class_name}")
      logger.warn("UNSUBSCRING #{event_path} from #{queue}, #{class_name}")
      Donaghy.storage.remove_from_set("donaghy_#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
      Donaghy.storage.remove_from_set("donaghy_event_paths", event_path)
    end

  end
end
