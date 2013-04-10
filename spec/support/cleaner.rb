RSpec.configure do |config|
  config.before do
    Donaghy.logger.info('storage flush')
    Donaghy.storage.flush
    Donaghy.reset
    Donaghy.configuration = {config_file: "spec/support/test_config.yml" }

    if Donaghy.configuration[:storage] == :sqs
      while Donaghy.root_queue.length > 0
        msg = Donaghy.root_queue.receive
        msg.acknowledge if msg
      end

      while Donaghy.default_queue.length > 0
        msg = Donaghy.default_queue.receive
        msg.acknowledge if msg
      end
    else
      Donaghy.logger.info('root queue destroy')
      Donaghy.root_queue.destroy if Donaghy.root_queue.exists?
      Donaghy.default_queue.destroy if Donaghy.default_queue.exists?
    end

    if defined?(TestLoadedService)
      TestLoadedService.reset
    end
  end
end
