require 'spec_helper'

module Donaghy
  describe EventSubscriber do
    let(:event_worker) { EventSubscriber.new }
    let(:event_path) { "/event_path/test_service/test_event/" }
    let(:queue) { "test_service_queue" }
    let(:class_name) { "test_class_name" }

    let(:serialized_event_data) { ListenerSerializer.dump(queue: queue, class_name: class_name) }
    let(:subscription_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    let(:mock_queue) { double(:queue, publish: true) }

    let(:local_storage) { Donaghy.local_storage }
    let(:remote_storage) { Donaghy.storage }

    before do
      Donaghy.stub(:root_queue).and_return(mock_queue)
    end

    describe "#subscribe" do

      before do
        # it publishes the event
        mock_queue.should_receive(:publish).with(an_instance_of(Event))
        EventSubscriber.new.subscribe(event_path, queue, class_name)
      end

      it "stores the subscription locally" do
        expect(local_storage.member_of?(LOCAL_DONAGHY_EVENT_PATHS, event_path)).to be_true
        expect(local_storage.member_of?("#{LOCAL_PATH_PREFIX}#{event_path}", serialized_event_data)).to be_true
      end
    end


    describe "handling event to subscribe a path" do
      before do
        event_worker.handle_subscribe(subscription_event)
      end

      it "subscribes on remote storage" do
        expect(remote_storage.member_of?(DONAGHY_EVENT_PATHS, event_path)).to be_true
        expect(remote_storage.member_of?("#{PATH_PREFIX}#{event_path}", serialized_event_data)).to be_true
      end

      it "adds the queue list to the donaghy_queues" do
        remote_storage.member_of?(DONAGHY_QUEUES_PATH, queue).should be_true
      end

      it "updates the local cache of the remote storage" do
        expect(local_storage.member_of?(DONAGHY_EVENT_PATHS, event_path)).to be_true
      end

    end
  end
end
