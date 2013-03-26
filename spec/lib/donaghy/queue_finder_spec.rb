require 'spec_helper'

module Donaghy

  describe QueueFinder do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:queue_finder) { QueueFinder.new(event_path)}

    let(:subscription_event) do
      Event.from_hash({
          payload: {
              event_path: event_path,
              queue: queue,
              class_name: class_name,
          }
      })
    end

    before do
      #setup the listener
      SubscribeToEventWorker.new.handle_subscribe("donaghy/subscribe_to_path", subscription_event)
    end

    it "should QueueFinder.all_listeners" do
      QueueFinder.all_listeners.should == {
          event_path => [{queue: queue, class_name: class_name}]
      }
    end

    describe "#find" do
      let(:results) { queue_finder.find }

      it "should find one" do
        results.length.should == 1
      end

      it "should be a hash of queue, class" do
        results.first[:queue].should == queue
        results.first[:class_name].should == "KlassHandler"
      end

      describe "with a wildcard" do
        let(:results) { queue_finder.find }
        let(:wildcard_subscription_event) do
          Event.from_hash({
              payload: {
                  event_path: "bla*/c*",
                  queue: queue,
                  class_name: class_name,
              }
          })
        end

        before do
          SubscribeToEventWorker.new.handle_subscribe("donaghy/subscribe_to_path", wildcard_subscription_event)
        end

        it "should find two" do
          results.length.should == 2
        end

        it "should be a hash of message_queue, class" do
          results.last[:queue].should == queue
          results.last[:class_name].should == "KlassHandler"
        end

      end

    end
  end

end
