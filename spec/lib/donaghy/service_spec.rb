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
      pending "this looks to be an rspec problem"
      [Donaghy.root_event_path, Donaghy.local_service_host_queue].each do |queue|
        EventSubscriber.any_instance.should_receive(:subscribe).with(BaseService.ping_pattern, queue, BaseService.name).once.and_return(true)
      end
      BaseService.subscribe_to_pings
    end

    it "should unsubscribe from the host-only pings" do
      EventUnsubscriber.any_instance.should_receive(:unsubscribe).with(BaseService.ping_pattern, Donaghy.local_service_host_queue, BaseService.name).once.and_return(true)
      BaseService.unsubscribe_host_pings
    end

    it "should #root_trigger" do
      mock_queue = mock(:queue, publish: true)
      Donaghy.stub(:root_queue).and_return(mock_queue)
      mock_queue.should_receive(:publish).with(an_instance_of(Event)).and_return(true)
      base_service.root_trigger(event_path, payload: "cool")
    end

    it "should #trigger" do
      mock_queue = mock(:queue, publish: true)
      Donaghy.stub(:root_queue).and_return(mock_queue)
      mock_queue.should_receive(:publish) do |event|
        event.path.should == "#{root_path}/base_service/#{event_path}"
        event.payload.cool.should be_true
        true
      end
      base_service.trigger(event_path, payload: {cool: true})
    end

    it "should BaseService.subscribe_to_global_events" do
      EventSubscriber.any_instance.should_receive(:subscribe).with(subscribed_event_path, root_path, BaseService.name).once.and_return(true)
      BaseService.subscribe_to_global_events
    end

    it "should BaseService.unsubscribe_all_instances" do
      pending "appears to be an rspec problem"
      EventUnsubscriber.any_instance.should_receive(:unsubscribe).with(subscribed_event_path, root_path, BaseService.name).once.and_return(true)
      [Donaghy.local_service_host_queue, root_path].each do |ping_queue|
        EventUnsubscriber.any_instance.should_receive(:unsubscribe).with(BaseService.ping_pattern, ping_queue, BaseService.name).once.and_return(true)
      end
      BaseService.unsubscribe_all_instances
    end

    it "should handle distributing events" do
      event = Event.from_hash(path: event_path, payload: "something")
      BaseService.new.distribute_event(event)
      BaseService.handler.pop.last.should == event
    end


  end


end
