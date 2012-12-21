require 'spec_helper'

module Donaghy

  describe Service do
    before do
      class BaseService
        include Donaghy::Service
        class_attribute :handler
        self.handler = Queue.new

        receives "sweet/*", :handle_sweet_pie

        def handle_sweet_pie(path, evt)
          self.class.handler << [path, evt]
        end
      end
    end

    let(:subscribed_event_path) { "sweet/*" }
    let(:event_path) { "sweet/pie" }
    let(:root_path) { Donaghy.root_event_path }
    let(:event_path_with_root) { "#{root_path}/#{event_path}"}
    let(:base_service) { BaseService.new }

    it "should #root_trigger" do
      EventDistributerWorker.should_receive(:perform_async).with(event_path, hash_including(payload: "cool")).and_return(true)
      base_service.root_trigger(event_path, payload: "cool")
    end

    it "should #trigger" do
      EventDistributerWorker.should_receive(:perform_async).with("#{root_path}/base_service/#{event_path}", hash_including(payload: "cool")).and_return(true)
      base_service.trigger(event_path, payload: "cool")
    end

    it "should BaseService.subscribe_to_global_events" do
      SubscribeToEventWorker.should_receive(:perform_async).with(subscribed_event_path, root_path, BaseService.name).once.and_return(true)
      BaseService.subscribe_to_global_events
    end

    it "should BaseService.unsubscribe_all_instances" do
      UnsubscribeFromEventWorker.should_receive(:perform_async).with(subscribed_event_path, root_path, BaseService.name).once.and_return(true)
      BaseService.unsubscribe_all_instances
    end

    it "should handle the perform from sidekiq" do
      event = Event.from_hash(path: event_path, payload: "something")
      BaseService.new.perform(event_path, event.to_hash)
      BaseService.handler.pop.last.should == event
    end


  end


end
