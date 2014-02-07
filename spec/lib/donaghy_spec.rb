require 'spec_helper'
require 'socket'

module Donaghy

  describe Donaghy do

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

    it "should have a hostname" do
      Donaghy.hostname.should == Socket.gethostname
    end

    describe "#configuration=" do

      let(:donaghy_resources_config) do
        StringIO.new({
            message_queue: [:sqs, {cool: true}]
        }.to_yaml)
      end

      let(:donaghy_config) do
        StringIO.new({
            bob: 'is_uncle'
        }.to_yaml)
      end

      context "when there is a /mnt/configs/donaghy.yml" do

        before do
          File.should_receive(:open).with('/mnt/configs/donaghy_resources.yml').and_return(donaghy_resources_config)
          File.should_receive(:open).with(File.expand_path('config/donaghy.yml')).and_return(donaghy_config)
          Donaghy.reset
          #Donaghy.configuration = {}
        end

        it "reads from the donaghy_resources file" do
          expect(Donaghy.message_queue.opts[:cool]).to be_true
        end

        it "also still reads from config/donaghy.yml" do
          expect(Donaghy.configuration[:bob]).to eq('is_uncle')
        end

      end

    end


  end
  
end
