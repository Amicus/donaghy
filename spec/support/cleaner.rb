RSpec.configure do |config|
  config.before do
    Donaghy.storage.flush
    Donaghy.reset
    Donaghy.configuration = {config_file: "spec/support/test_config.yml" }
    Donaghy.root_queue.destroy if Donaghy.root_queue.exists?
    Donaghy.default_queue.destroy if Donaghy.default_queue.exists?
    if defined?(TestLoadedService)
      TestLoadedService.reset
    end
  end
end
