require 'zk-server'

module Donaghy
  TEST_CONFIG = YAML.load_file("spec/support/test_config.yml")
end

ZK_SPEC_SERVER_PORT = 21811

ZK_SPEC_SERVER = ZK::Server.new do |config|
  config.client_port = ZK_SPEC_SERVER_PORT
  config.enable_jmx = true
  config.force_sync = false
end

RSpec.configure do |config|
  config.before(:suite) do
    Donaghy.logger.info("running zk server and setting up Donaghy test configuration")
    ZK_SPEC_SERVER.run
  end

  config.before(:each) do
    Sidekiq.options[:queues] = []
    Donaghy.configuration = Donaghy::TEST_CONFIG
  end

end

