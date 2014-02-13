require 'donaghy/listener_updater'

module Donaghy
  class EventSubscriber
    include Donaghy::Service

    EVENT_PATH = "donaghy/subscribe_to_path"

    receives EVENT_PATH, :handle_subscribe

    #subscribes locally and then fires an event to put the listener into the shared storage
    def subscribe(event_path, queue, class_name)
      local_subscribe(event_path, queue, class_name)
      publish_global_subscribe(event_path, queue, class_name)
    end

    # local from code in this process
    def local_subscribe(event_path, queue, class_name)
      logger.info("EventSubscriber: local registering #{event_path} to #{queue}, #{class_name}")
      local_storage.add_to_set(LOCAL_DONAGHY_EVENT_PATHS, event_path)
      local_storage.add_to_set("#{LOCAL_PATH_PREFIX}#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
    end

    def publish_global_subscribe(event_path, queue, class_name)
      Donaghy.root_queue.publish(Event.from_hash({
          path: "donaghy/subscribe_to_path",
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name
          }
      }))
    end

    # remote - code executed in this process from remote events
    def handle_subscribe(evt)
      payload = evt.payload
      event_path, queue, class_name = payload.event_path, payload.queue, payload.class_name
      global_subscribe(event_path, queue, class_name)
    end

    # actually write the listener to the remote storage - usually called from
    # an event being handled
    def global_subscribe(event_path, queue, class_name)
      logger.info("EventSubscriber: global registering #{event_path} to #{queue}, #{class_name}")
      remote_storage.add_to_set(DONAGHY_QUEUES_PATH, queue)
      remote_storage.add_to_set(DONAGHY_EVENT_PATHS, event_path)
      remote_storage.add_to_set("#{PATH_PREFIX}#{event_path}", ListenerSerializer.dump({queue: queue, class_name: class_name}))
      update_local_events
    end

  private
    def remote_storage
      Donaghy.storage
    end

    def local_storage
      Donaghy.local_storage
    end

    def update_local_events
      listener_updater = ListenerUpdater.new(local: local_storage, remote: remote_storage)
      listener_updater.update_local_event_paths
      listener_updater.terminate
    end

  end
end
