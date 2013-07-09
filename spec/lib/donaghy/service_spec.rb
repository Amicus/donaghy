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
        event.timer.should == 10
        event.value.should == 5
        event.dimensions[:organization].should == "United Wolf Lovers"
        event.dimensions[:user].should == "Jack Black"
        event.context.should == 'peregrine'
        true
      end
      base_service.trigger(event_path, payload: {cool: true}, timer: 10, value: 5, context: 'peregrine', dimensions: {organization: "United Wolf Lovers", user: "Jack Black"})
    end

    it "should BaseService.subscribe_to_global_events" do
      EventSubscriber.any_instance.should_receive(:subscribe).with(subscribed_event_path, Donaghy.default_queue_name, BaseService.name).once.and_return(true)
      BaseService.subscribe_to_global_events
    end

    it "should BaseService.unsubscribe_all_instances" do
      EventUnsubscriber.any_instance.should_receive(:unsubscribe).with(subscribed_event_path, Donaghy.default_queue_name, BaseService.name).once.and_return(true)
      BaseService.unsubscribe_all_instances
    end

    it "should handle distributing events" do
      event = Event.from_hash(path: event_path, payload: "something")
      BaseService.new.distribute_event(event)
      BaseService.handler.pop.last.should == event
    end
  end
end
