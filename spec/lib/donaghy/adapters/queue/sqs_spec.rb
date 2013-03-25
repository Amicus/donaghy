require 'spec_helper'
require 'donaghy/adapters/queue/sqs'

module Donaghy
  module Queue
    describe SQS do

      it "should publish and receive an event" do
        queue = SQS.find_by_name("test")
        queue.publish(payload: {cool:true})
        message = queue.receive
        message.payload.cool.should == true
      end

    end

  end
end
