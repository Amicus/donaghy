require 'spec_helper'

module Donaghy
  describe ListenerSerializer do
    let(:encoded_string) { "my_queue,MyKlass" }
    let(:listener_hash) { {queue: "my_queue", class_name: "MyKlass"} }

    it "should load" do
      ListenerSerializer.load(encoded_string).should == listener_hash
    end

    it "should dump" do
      ListenerSerializer.dump(listener_hash).should == encoded_string
    end



  end
end
