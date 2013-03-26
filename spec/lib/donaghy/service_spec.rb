require 'spec_helper'

module Donaghy

  describe Service do
    before do
      class BaseService
        include Donaghy::Service

        class_attribute :handler
        self.handler = ::Queue.new

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

    it "should have a BaseService.ping_pattern" do
      # class name of BaseService is Donaghy::BaseService so klass.underscore is donaghy/base_service
      BaseService.ping_pattern.should == "#{Donaghy.configuration[:name]}/donaghy/base_service/ping*"
    end

    it "should subscribe to pings" do
      [Donaghy.root_event_path, Donaghy.local_service_host_queue].each do |queue|
        SubscribeToEventWorker.should_receive(:perform_async).with(BaseService.ping_pattern, queue, BaseService.name).once.and_return(true)
      end
      BaseService.subscribe_to_pings
    end

    it "should unsubscribe from the host-only pings" do
      UnsubscribeFromEventWorker.should_receive(:perform_async).with(BaseService.ping_pattern, Donaghy.local_service_host_queue, BaseService.name).once.and_return(true)
      BaseService.unsubscribe_host_pings
    end

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
      [Donaghy.local_service_host_queue, root_path].each do |ping_queue|
        UnsubscribeFromEventWorker.should_receive(:perform_async).with(BaseService.ping_pattern, ping_queue, BaseService.name).once.and_return(true)
      end
      BaseService.unsubscribe_all_instances
    end

    it "should handle the perform from sidekiq" do
      event = Event.from_hash(path: event_path, payload: "something")
      BaseService.new.perform(event_path, event.to_hash)
      BaseService.handler.pop.last.should == event
    end


  end


end
