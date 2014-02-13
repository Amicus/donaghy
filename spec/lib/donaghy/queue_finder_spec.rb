require 'spec_helper'
require 'donaghy/listener_updater'

module Donaghy

  describe QueueFinder do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }

    context "with local lookup" do

      before do
        #setup the listener
        EventSubscriber.new.local_subscribe(event_path, queue, class_name)
      end

      let(:queue_finder) { QueueFinder.new(event_path, Donaghy.local_storage, local: true)}

      describe "#find" do

        subject { queue_finder.find }

        its(:length) { should == 1 }

        it "returns array of hashes of queue, class" do
          subject.first[:queue].should == queue
          subject.first[:class_name].should == "KlassHandler"
        end

        context "with a wildcard" do
          let(:wildcard_path) { "bla.*/c.*" }

          before do
            EventSubscriber.new.local_subscribe(wildcard_path, queue, class_name)
          end

          its(:length) { should == 2 }

          it "returns array of hashes of message_queue, class" do
            subject.last[:queue].should == queue
            subject.last[:class_name].should == "KlassHandler"
          end

        end
      end
    end

    context "with remote lookup" do
      let(:queue_finder) { QueueFinder.new(event_path, Donaghy.local_storage) }

      before do
        #setup the listener
        EventSubscriber.new.global_subscribe(event_path, queue, class_name)
      end

      describe "#find" do

        subject { queue_finder.find }

        its(:length) { should == 1 }

        it "returns array of hashes of queue, class" do
          subject.first[:queue].should == queue
          subject.first[:class_name].should == "KlassHandler"
        end

        context "with a wildcard" do
          let(:wildcard_path) { "bla.*/c.*" }

          before do
            EventSubscriber.new.global_subscribe(wildcard_path, queue, class_name)
          end

          subject { queue_finder.find }

          its(:length) { should == 2 }

          it "is a hash of message_queue, class" do
            subject.last[:queue].should == queue
            subject.last[:class_name].should == "KlassHandler"
          end

        end
      end
    end
  end

end
