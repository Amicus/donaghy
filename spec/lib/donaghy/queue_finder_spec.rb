require 'spec_helper'

module Donaghy

  describe QueueFinder do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:queue_finder) { QueueFinder.new(event_path)}

    before do
      #setup the listener
      SubscribeToEventWorker.new.perform(event_path, queue, class_name)
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

        before do
          #subscribe to a wildcard
          SubscribeToEventWorker.new.perform("bla*/c*", queue, class_name)
        end

        it "should find two" do
          results.length.should == 2
        end

        it "should be a hash of queue, class" do
          results.last[:queue].should == queue
          results.last[:class_name].should == "KlassHandler"
        end

      end

    end
  end

end
