CONFIG = {
      redis: {
          url: "redis://localhost:6379"
      }
  }

RSpec.configure do |config|
  config.before(:suite) do
    Donaghy.configuration = CONFIG
  end
end
