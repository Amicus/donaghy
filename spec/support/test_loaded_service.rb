class TestLoadedService
  include Donaghy::Service
  class_attribute :holder
  self.holder = Queue.new

  EVENT_PATH = "donaghy/test/holder"

  def self.reset
    self.holder.clear
  end

  receives EVENT_PATH, :handle_test_holder

  def handle_test_holder(evt)
    self.class.holder << evt
  end

end
