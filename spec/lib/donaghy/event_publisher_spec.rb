require 'spec_helper'
require 'donaghy/event_publisher'

module Donaghy
  describe EventPublisher do
    let(:publisher) { EventPublisher.new }

    after { publisher.stop if publisher.alive? }
    
    describe "#low_priority_trigger" do
      let(:path) { "path/to/some/event" }

      it "asynchronously queues the message" do
        expect { publisher.low_priority_trigger(path) }.to_not raise_error
      end

    end

  end
end
