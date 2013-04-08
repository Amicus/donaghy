require 'spec_helper'

module Donaghy

  describe Donaghy do
    it "should be true" do
      true.should == true
    end

    it "should set message queue via a string" do
      Donaghy.reset
      Donaghy.configuration[:message_queue] = 'sqs'
      Donaghy.message_queue.should be_a(Donaghy::MessageQueue::Sqs)
    end

    it "should set the message queue with an array and pass args" do
      Donaghy.reset
      Donaghy.configuration[:message_queue] = [:sqs, {cool: true}]
      Donaghy.message_queue.opts[:cool].should be_true
    end


  end
  
end
