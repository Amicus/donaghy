require 'spec_helper'

module Donaghy

  describe Donaghy do

    it "should raise on a missing config file" do
      ->() { Donaghy.configuration = {config_file: "/path/to/no/file.yml"} }.should raise_error(MissingConfigurationFile)
    end

    it "should have a local_service_host_queue" do
      Donaghy.local_service_host_queue.should == "donaghy_#{Donaghy.configuration[:name]}_#{Socket.gethostname.gsub(/\./, '_')}"
    end

  end

  describe "Integration Test" do
    let(:failover_manager) { Donaghy.actor_node_manager }
    let(:server) { Donaghy.server }

    let(:subscribed_event_path) { "sweet/*" }
    let(:event_path) { "sweet/pie" }
    let(:root_path) { Donaghy.root_event_path }
    let(:event_path_with_root) { "#{root_path}/#{event_path}"}
    let(:base_service) { BaseService.new }
    let(:node_path) { "/redis_failover/nodes" }
    let(:zk) { Donaghy.zk }

    after do
      failover_manager.stop
      server.stop
    end

    before do

      class ::TestLoadedService
        # ::TestLoadedService is defined in support, so just setting up listeners
        # for here, that's why it DOES NOT include Donaghy::Service

        VERSION = "custom_version"

        class_attribute :handler
        self.handler = Queue.new

        receives "sweet/*", :handle_sweet_pie

        def handle_sweet_pie(path, evt)
          logger.info("received on TestLoadedService: #{[path, evt].inspect}")
          self.class.handler << [path, evt]
        end
      end

      failover_manager.start

      #we want the redis to be over on the redis_failover now
      Donaghy.reset_redis
      Donaghy.configuration = Donaghy::TEST_CONFIG

      #bootstrap the failover manager here
      if zk.exists?(node_path)
        zk.set("/redis_failover/nodes", "{\"master\":\"localhost:6379\",\"slaves\":[],\"unavailable\":[]}")
      else
        zk.create("/redis_failover/nodes", "{\"master\":\"localhost:6379\",\"slaves\":[],\"unavailable\":[]}")
      end

      Donaghy.redis.with {|conn| conn.should be_a(RedisFailover::Client)}

      server.start

      root_path.should == "donaghy_test"

    end

    it "should have an event go through the whole system" do
      Celluloid.exception_handler do |ex|
        Donaghy.logger.error("caught error: #{ex.inspect}")
      end
      puts "waiting for subscribed"
      wait_till_subscribed
      it_should_register_the_configuration

      TestLoadedService.new.root_trigger("sweet/pie", payload: true)
      puts "before integration pop"
      Timeout.timeout(2) do
        TestLoadedService.handler.pop.last.payload.should be_true
      end

      it_should_ping_on_root_path
      it_should_ping_on_host_only_path

      puts "after integration"
    end

    def it_should_ping_on_root_path
      puts "pinging"
      Donaghy.event_publisher.ping(Donaghy.configuration[:name], TestLoadedService.name, "sweet/pie", id: 'test')

      Timeout.timeout(2) do
        message = TestLoadedService.handler.pop
        payload = message.last.payload
        payload.should include(
            'version' => TestLoadedService.service_version,
            'id' => 'test'
        )
        payload.should include('configuration')
        payload.should include('received_at')
      end
    end

    def it_should_ping_on_host_only_path
      puts "pinging"

      Donaghy.event_publisher.ping(Donaghy.configuration[:name], TestLoadedService.name, "sweet/pie", host: Socket.gethostname, id: 'test')

      Timeout.timeout(2) do
        message = TestLoadedService.handler.pop
        payload = message.last.payload
        payload.should include(
            'version' => TestLoadedService.service_version,
            'id' => 'test'
        )
        payload.should include('configuration')
        payload.should include('received_at')
      end
    end

    def it_should_register_the_configuration
      zk_obj = Marshal.load(Donaghy.zk.get("/donaghy/#{Donaghy.configuration[:name]}/#{Socket.gethostname}").first)
      zk_obj.should == {
                donaghy_configuration: Donaghy.configuration.to_hash,
                service_versions: server.service_versions
      }
      zk_obj[:service_versions]['TestLoadedService'].should == 'custom_version'
    end

    def wait_till_subscribed
      Timeout.timeout(3) do
        until subscribed?
          sleep 0.1
        end
      end
   # rescue Timeout::Error
    #  binding.pry
    end

    def wait_for(path, timeout = 25)
      queue = Queue.new
      zk.register(path) do |event|
        queue.push(:path_exists)
      end
      queue.push(:path_exists) if zk.exists?(path, :watch => true)
      Timeout.timeout(timeout) do
        queue.pop.should == :path_exists
      end
    end

    def subscribed?
      QueueFinder.new(subscribed_event_path).find.length > 0
    end


  end

end
