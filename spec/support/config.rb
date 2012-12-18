CONFIG = YAML.load_file("spec/support/test_config.yml")

RSpec.configure do |config|
  config.before(:suite) do
    Donaghy.configuration = CONFIG
  end
end
