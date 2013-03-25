require 'spec_helper'

module Donaghy

  describe EventDistributerWorker do
    let(:event_path) { "blah/cool" }
    let(:queue) { "testQueue" }
    let(:class_name) { "KlassHandler" }
    let(:event) { Event.new(path: event_path, payload: true)}
    let(:queue_finder) { QueueFinder.new(event_path)}

    class KlassHandler
      include Donaghy::Service
      donaghy_options = {:queue => "testQueue"}
    end

    before do
      SubscribeToEventWorker.new.perform(event_path, queue, class_name)
    end

    it "should distribute work" do
      EventDistributerWorker.new.perform(event_path, event.to_hash)
      Donaghy.redis do |conn|
        conn.scard(queue).should == 1
      end
    end

  end


end
