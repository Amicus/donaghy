require 'spec_helper'
require 'donaghy/sidekiq_runner'

module Donaghy
  describe SidekiqRunner do

      class SomeGuy
        include Donaghy::Service
        class_attribute :holder
        self.holder = Queue.new

        def perform(*args)
          self.class.holder << args
        end
      end

      let(:sidekiq_event) {
        Event.from_hash({
            path: "#{Donaghy.root_event_path}/#{Service::SIDEKIQ_EVENT_PREFIX}donaghy/some_guy",
            payload: {
              args: [1,2,3]
            }
        })
      }

      before do
        Donaghy.configuration[:services].should_not include(SomeGuy.to_s.underscore)
      end

      it "should receive them even if not subscribed" do
        SidekiqRunner.new.handle_perform(sidekiq_event)

        Timeout.timeout(1) do
          SomeGuy.holder.pop.should == [1,2,3]
        end
      end

  end
end
