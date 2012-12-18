require 'spec_helper'

module Donaghy

  describe "Integration Test" do

    after do
      server.stop
    end

    before do

      # this is defined in support, so just setting up listeners
      # for here, that's why it doesn't include Donaghy::Service
      class ::TestLoadedService
        class_attribute :handler
        self.handler = Queue.new

        receives "sweet/*", :handle_sweet_pie

        def handle_sweet_pie(path, evt)
          logger.info("received on TestLoadedService: #{[path, evt].inspect}")
          self.class.handler << [path, evt]
        end
      end

      server.start

      root_path.should == "donaghy_test"

    end

    let(:server) { Donaghy.server }

    let(:subscribed_event_path) { "sweet/*" }
    let(:event_path) { "sweet/pie" }
    let(:root_path) { Donaghy.root_event_path }
    let(:event_path_with_root) { "#{root_path}/#{event_path}"}
    let(:base_service) { BaseService.new }

    it "should have an event go through the whole system" do
      Celluloid.exception_handler do |ex|
        Donaghy.logger.error("caught error: #{ex.inspect}")
      end
      puts "waiting for subscribed"
      wait_till_subscribed
      TestLoadedService.new.root_trigger("sweet/pie", payload: true)
      puts "before integration pop"
      Timeout.timeout(2) do
        TestLoadedService.handler.pop.last.payload.should be_true
      end
      puts "after integration"
    end

    def wait_till_subscribed
      Timeout.timeout(3) do
        until subscribed?
          sleep 0.1
        end
      end
    rescue Timeout::Error
      binding.pry
    end

    def subscribed?
      QueueFinder.new(subscribed_event_path).find.length > 0
    end


  end

end
