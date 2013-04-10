require 'spec_helper'
require 'json'

module Donaghy

  describe Event do
    let(:event_path) { "cool_beans/cool" }
    let(:event) { Event.new(path: event_path) }

    it "should from_json" do
      Event.from_json(event.to_json).should == event
    end

    it "should load from hash" do
      Event.from_hash(event.to_hash).should == event
    end

    it "should set the generated_at at creation" do
      event.generated_at.should be_a(Time)
    end

    it "should save the path" do
      event.path.should == event_path
    end

    it "should to_hash" do
      event.to_hash[:path].should == event_path
    end

    it "should to_json" do
      JSON.load(event.to_json)['path'].should == event_path
    end

    it "should take options to to_json" do
      event.to_json(some: 'op').should be_a String
    end

    it "should show two identical events as equal" do
      event2 = Event.new(path: event_path)
      event2.should == event
    end

    it "should have dates go back and forth through json" do
      generated_at = event.generated_at
      json = event.to_json
      new_event = Event.from_json(json)
      new_event.generated_at.to_i.should == generated_at.to_i
    end

    it "should inspect" do
      event.inspect.should == event.to_hash.inspect
    end

  end

end
