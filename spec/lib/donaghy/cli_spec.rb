require 'spec_helper'
require 'donaghy/cli'

module Donaghy

  describe CLI do
    describe "console" do
      let(:argv) { %w(console) }

      it "should load the console" do
        Binding.any_instance.should_receive(:pry).and_return(true)
        CLI.new(argv)
      end

    end

    describe "publish" do
      let(:event_path) { "path/to/event" }
      let(:payload) { "some_payload" }
      let(:argv) { ['publish', event_path, payload]}

      it "should publish an event" do
        Donaghy.event_publisher.should_receive(:root_trigger).with(event_path, payload: payload).and_return(true)
        CLI.new(argv)
      end

    end

    describe "listall" do
      let(:argv) { ['listall']}

      it "should QueueFinder.list_all" do
        QueueFinder.should_receive(:list_all).and_return "testOutputFromListAll"
        CLI.new(argv)
      end



    end


  end

end
