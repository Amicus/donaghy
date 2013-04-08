RSpec.configure do |config|
  config.before do
    Donaghy.storage.flush
    Donaghy.reset
    Donaghy.configuration = {config_file: "spec/support/test_config.yml" }

    #Donaghy.root_queue.destroy if Donaghy.root_queue.exists?
    #Donaghy.default_queue.destroy if Donaghy.default_queue.exists?

    while Donaghy.root_queue.length > 0
      msg = Donaghy.root_queue.receive
      msg.acknowledge if msg
    end

    while Donaghy.default_queue.length > 0
      msg = Donaghy.default_queue.receive
      msg.acknowledge if msg
    end


    if defined?(TestLoadedService)
      TestLoadedService.reset
    end
  end
end
