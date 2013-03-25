module Donaghy
  class UnsubscribeFromEventWorker
    include Donaghy::Service
    donaghy_options = {:queue => ROOT_QUEUE}

    receives "donaghy/unsubscribe_from_path", :handle_unsubscribe

    def handle_unsubscribe(path, evt)
      payload = evt.payload
      event_path, queue, class_name = payload.event_path, payload.queue, payload.class_name
      logger.warn("UNSUBSCRING #{event_path} from #{queue}, #{class_name}")
      Donaghy.storage.unset("donaghy_#{event_path}")
      Donaghy.storage.remove_from_set("donaghy_event_paths", event_path)
    end

  end
end
