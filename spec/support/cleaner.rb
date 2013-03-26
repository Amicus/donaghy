RSpec.configure do |config|
  config.before do
    Donaghy.storage.flush!
    Donaghy.root_queue.destroy if Donaghy.root_queue.exists?
    Donaghy.reset
    Donaghy.configuration = {config_file: "spec/support/test_config.yml" }
  end
end
