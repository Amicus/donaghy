require 'spec_helper'
require 'donaghy/adapters/message_queue/sqs'

module Donaghy
  module MessageQueue
    describe Sqs do
      let(:sqs) { Donaghy.message_queue }

      it "should publish and receive an event" do
        queue = sqs.find_by_name(Donaghy::ROOT_QUEUE)
        queue.publish(Event.from_hash(payload: {cool:true}))
        message = queue.receive
        message.payload.cool.should == true
      end

      describe "regular queue characteristics" do
        let!(:queue) { sqs.find_by_name("testhead") }

        after do
          queue.destroy
        end

        it "should create a queue when one does not exist" do
         queue.exists?.should be_true
        end

        it "should have a name" do
          queue.name.should == 'testhead'
        end

      end

    end

  end
end
