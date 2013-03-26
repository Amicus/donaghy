require 'spec_helper'
require 'donaghy/adapters/message_queue/sqs'

module Donaghy
  module MessageQueue
    describe Sqs do

      it "should publish and receive an event" do
        queue = Sqs.find_by_name(Donaghy::ROOT_QUEUE)
        queue.publish(Event.from_hash(payload: {cool:true}))
        message = queue.receive
        message.payload.cool.should == true
      end

      it "should create a queue when one does not exist" do
        queue = Sqs.find_by_name("testhead")
        queue.exists?.should be_true
        queue.destroy
      end

    end

  end
end
