require 'spec_helper'

module Donaghy

  describe HeartBeater do
    let(:event) do
      Event.from_hash({
        path: 'donaghy/hi'
      })
    end

    let(:timeout) { 1 }

    let(:beater) { HeartBeater.new(event, timeout) }

    after do
      beater.stop if beater.alive?
    end

    it "should beat the event" do
      event.should_receive(:heartbeat).at_least(1).times.and_return(true)
      beater.beat
    end

    it "should set the timer" do
      beater.timer.should be_nil
      beater.beat
      beater.timer.should_not be_nil
      beater.timer.interval.should == timeout
    end
  end
end
