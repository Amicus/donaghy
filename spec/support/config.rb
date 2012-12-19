module Donaghy
  TEST_CONFIG = YAML.load_file("spec/support/test_config.yml")
end

RSpec.configure do |config|
  config.before(:suite) do
    Donaghy.configuration = Donaghy::TEST_CONFIG
  end
end
