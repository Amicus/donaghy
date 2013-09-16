require 'spec_helper'

module Donaghy
  describe EventPublisher do

    describe "triggering an event via the event publisher " do
      before do
        @publisher = EventPublisher.new
        @publisher.stub(:global_publish).and_return(:true)
      end
      it "should fire the event into donaghy" do
        @publisher.should_receive(:global_publish)
        @publisher.trigger("fake")
      end
    end

  end
end