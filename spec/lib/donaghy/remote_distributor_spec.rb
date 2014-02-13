require 'spec_helper'
require 'donaghy/listener_updater'

module Donaghy

  describe RemoteDistributor do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:event) { Event.new(path: event_path, payload: true)}
    let(:mock_queue) { mock(:message_queue, publish: true)}

    let(:listener_updater) { ListenerUpdater.new(local: Donaghy.local_storage, remote: Donaghy.storage) }

    after do
      listener_updater.terminate if listener_updater.alive?
    end

    describe "with a single listener" do
      before do
        EventSubscriber.new.global_subscribe_to_event(event_path, queue, class_name)
        listener_updater.update_local_event_paths
      end

      it "should distribute work" do
        Donaghy.should_receive(:queue_for).with(queue).and_return(mock_queue)
        mock_queue.should_receive(:publish).with(an_instance_of(Event)).and_return(true)
        RemoteDistributor.new.handle_distribution(event)
      end

      it "shouldn't error when no subscription" do
        Donaghy.storage.flush
        ->() { RemoteDistributor.new.handle_distribution(event) }.should_not raise_error
      end
    end

    describe "when mulitple classes from the same cluster listen to the same event" do
      before do
        class ListenerOne
          include Donaghy::Service
          receives "blah/cool", :handle_shared
        end

        class ListenerTwo
          include Donaghy::Service
          receives "blah/cool", :handle_shared
        end
        EventSubscriber.new.global_subscribe_to_event(event_path, queue, "ListenerOne")
        EventSubscriber.new.global_subscribe_to_event(event_path, queue, "ListenerTwo")
        listener_updater.update_local_event_paths
      end

      it "should only send one message from the global queue to the cluster queue" do
        Donaghy.stub(:queue_for).and_return(queue)
        queue.stub(:publish).and_return(true)
        Donaghy.should_receive(:queue_for).with(queue).once
        RemoteDistributor.new.handle_distribution(event)
      end
    end

  end


end
