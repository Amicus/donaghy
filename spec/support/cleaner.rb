RSpec.configure do |config|
  config.before do
    Donaghy.redis.with do |redis|
      redis.flushdb
    end
  end
  config.after(:suite) do
    Donaghy.zk.close!
    ZK_SPEC_SERVER.shutdown
  end

end
