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

    describe "#register_in_zk" do
      before do
        server.register_in_zk
      end

      # this is also tested in the integration specs
      it "should write out the configuration" do
        zk_obj = Marshal.load(Donaghy.zk.get("/donaghy/#{Donaghy.configuration[:name]}/#{Socket.gethostname}").first)
        zk_obj.should == {
                  donaghy_configuration: Donaghy.configuration.to_hash,
                  service_versions: server.service_versions
        }
      end


      def zk
        Donaghy.zk
      end


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
      let(:host_specific_queue) { "donaghy_#{Donaghy.configuration[:name]}_#{Socket.gethostname.gsub(/\./, '_')}" }
      let(:sidekiq_queue_expected) {  ["global_event", host_specific_queue, alternate_queue] }

      before do
        server.setup_queues
        server.configure_sidekiq
      end

      it "should configure sidekiqs queues" do
        subject[:queues].should == sidekiq_queue_expected
      end

      it "should listen to the host and service specific queue (for checking)" do
        subject[:queues].should include(host_specific_queue)
      end

      it "should not dupe queues on a second call" do
        server.configure_sidekiq
        subject[:queues].should == sidekiq_queue_expected
      end

    end




  end
end
