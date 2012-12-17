RSpec.configure do |config|
  config.before do
    Donaghy.redis.with do |redis|
      redis.flushdb
    end
  end
end
