RSpec.configure do |config|
  config.before do
    Donaghy.storage.flush
    Donaghy.root_queue.destroy if Donaghy.root_queue.exists?
    Donaghy.default_queue.destroy if Donaghy.default_queue.exists?
    Donaghy.reset
    if defined?(TestLoadedService)
      TestLoadedService.reset
    end
    Donaghy.configuration = {config_file: "spec/support/test_config.yml" }
  end
end
