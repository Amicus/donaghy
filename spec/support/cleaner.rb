RSpec.configure do |config|
  config.before do
    Donaghy.storage.flush!
  end

end
