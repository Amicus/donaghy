require 'spec_helper'

module Donaghy
  module Middleware

    describe Stats do
      let(:manager) { man = mock(:manager, name: "test_mock_manager"); man.stub_chain(:async, :event_handler_finished).and_return(true); man }
      let(:event_handler) { EventHandler.new(manager) }

      let(:event) do
        Event.from_hash({
          path: "ohhi",
          payload: {cool: true}
        })
      end

      before do
        Donaghy.middleware do |m|
          m.clear
          m.add Stats
        end
      end

      after do
        event_handler.terminate if event_handler.alive?
      end

      describe "when successful" do
        before do
          event_handler.handle(event)
        end

        it "should inc the complete count" do
          storage.get('complete').to_i.should == 1
        end

        it "should have in progress back down to 0 when its done" do
          storage.get('inprogress_count').to_i.should == 0
        end

        it "should unset the inprogress id" do
          Array(storage.get('inprogress')).length.should == 0
        end

        it "should remove the inprogress event" do
          storage.get("inprogress:#{event.id}").should be_nil
        end

      end

      describe "when erroring" do
        before do
          counter = 0
          event.stub(:path) do |args|
            if counter == 0
              counter += 1
              raise StandardError
            end
            true
          end
          ->() { event_handler.handle(event) }.should raise_error(StandardError)
        end

        it "should not inc complete" do
          storage.get("complete").should be_nil
        end
        
        it "should cleanup inprogress" do
          storage.get('inprogress_count').to_i.should == 0
          Array(storage.get('inprogress')).should be_empty
          storage.get("inprogress:#{event.id}").should be_nil
        end

        it "should save a json representation of the failure" do
          JSON.parse(storage.get("failure:#{event.id}"))['exception'].should == 'StandardError'
        end

        it "should add the failure id to the failures set" do
          storage.member_of?('failures', event.id).should be_true
        end

        it "should inc the failed count and raise the standard error" do
          storage.get('failed').to_i.should == 1
        end

        describe "on its next successful pass through" do
          let(:second_eventhandler) { EventHandler.new(manager) }

          before do
            event.unstub(:path)
            second_eventhandler.handle(event)
          end

          after do
            second_eventhandler.terminate if second_eventhandler.alive?
          end

          it "should remove the failure id" do
            storage.member_of?('failures', event.id).should be_false
          end

          it "should delete the failures json" do
            storage.get("failure:#{event.id}").should be_nil
          end

        end
      end

      def storage
        Donaghy.storage
      end

    end
  end
end
