require 'spec_helper'
require 'donaghy/listener_updater'

module Donaghy
  describe ListenerUpdater do
    let(:remote_storage) { Donaghy.storage }
    let(:local_storage) { Donaghy.local_storage }

    let(:event_path) { "some/path" }

    subject { ListenerUpdater.new(remote: remote_storage, local: local_storage) }

    after do
      subject.terminate if subject.alive?
    end

    describe "#update_local_event_paths" do
      before do
        EventSubscriber.new.global_subscribe(event_path, 'some_queue', 'SomeClass')
        subject.update_local_event_paths
      end

      it "sets local_event_paths to remote_event_paths" do
        expect(local_storage.get(DONAGHY_EVENT_PATHS)).to eq(remote_storage.get(DONAGHY_EVENT_PATHS))
      end

      it "sets each event path to remote listeners" do
        remote_storage.get(DONAGHY_EVENT_PATHS).each do |event_path|
          expect(local_storage.get("#{PATH_PREFIX}#{event_path}")).to eq(remote_storage.get("#{PATH_PREFIX}#{event_path}"))
        end
      end

    end

  end
end
