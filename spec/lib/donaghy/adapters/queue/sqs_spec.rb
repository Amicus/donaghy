require 'spec_helper'
require 'donaghy/adapters/queue/sqs'

module Donaghy
  module Queue
    describe Sqs do

      it "should publish and receive an event" do
        queue = Sqs.find_by_name("test")
        queue.publish(Event.from_hash(payload: {cool:true}))
        message = queue.receive
        message.payload.cool.should == true
      end

    end

  end
end
