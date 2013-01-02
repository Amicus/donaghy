require 'spec_helper'

module Donaghy

  describe Server do
    #most of the real functionality is tested in the integration_spec.rb

    let(:server) { Server.new }
    let(:alternate_queue) { "ServiceTest" }
    before do
      @old_queue_name = Donaghy.configuration[:queue_name]
      Donaghy.configuration[:queue_name] = alternate_queue
    end

    after do
      Donaghy.configuration[:queue_name] = @old_queue_name
    end

    describe "#setup_queues" do
      subject { server.queues }

      before do
        server.setup_queues
      end

      it "should listen to Donaghy.configuration[:queue_name]" do
        should include(alternate_queue)
      end

      it "should listen to the ROOT_QUEUE" do
        should include(Donaghy::ROOT_QUEUE)
      end

    end

    describe "#configure_sidekiq" do
      subject { Sidekiq.options }
      let(:sidekiq_queue_expected) {  ["global_event", alternate_queue] }

      before do
        server.setup_queues
        server.configure_sidekiq
      end

      it "should configure sidekiqs queues" do
        subject[:queues].should == sidekiq_queue_expected
      end

      it "should not dupe queues on a second call" do
        server.configure_sidekiq
        subject[:queues].should == sidekiq_queue_expected
      end

    end




  end
end
