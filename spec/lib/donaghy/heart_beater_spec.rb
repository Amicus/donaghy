require 'spec_helper'

module Donaghy

  describe HeartBeater do
    let(:event) do
      Event.from_hash({
        path: 'donaghy/hi'
      })
    end

    let(:handler) { mock(:event_handler, alive?: true)}

    let(:timeout) { 1 }
    let(:beater) { HeartBeater.new(event, handler, timeout) }

    after do
      beater.terminate if beater.alive?
    end

    it "should beat the event with a timeout 3x the beaters timeout" do
      event.should_receive(:heartbeat).with(timeout*3).at_least(1).times.and_return(true)
      beater.beat
    end

  end
end
