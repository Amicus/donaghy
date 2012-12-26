require 'spec_helper'
require 'donaghy/cli'

module Donaghy

  describe CLI do
    describe "console" do
      let(:argv) { %w(console) }

      it "should load the console" do
        Binding.any_instance.should_receive(:pry).and_return(true)
        CLI.new(argv).parse
      end
    end

    describe "run" do
      let(:argv) { %w(run) }

      it "should start the server" do
        Donaghy.server.should_receive(:start).and_return(true)
        cli = nil
        Thread.new do
          cli = CLI.new(argv)
          cli.parse
        end
        #wait until the other thread is doing stuff
        until cli
          puts 'no cli'
          sleep 0.1
        end
        ->() { cli.interrupt }.should raise_error(Interrupt)
      end

    end

    describe "publish" do
      let(:event_path) { "path/to/event" }
      let(:payload) { "some_payload" }
      let(:argv) { ['publish', event_path, payload]}

      it "should publish an event" do
        Donaghy.event_publisher.should_receive(:root_trigger).with(event_path, payload: payload).and_return(true)
        CLI.new(argv).parse
      end
    end

    describe "listall" do
      let(:argv) { ['listall']}

      it "should QueueFinder.list_all" do
        QueueFinder.should_receive(:all_listeners).and_return "testOutputFromListAll"
        CLI.new(argv).parse
      end
    end
  end
end
