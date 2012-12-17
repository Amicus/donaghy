require 'spec_helper'

module Donaghy

  describe Server do
    let(:server) { Server.new }

    after do
      server.stop
    end

    it "should start" do
      ->() { server.start }.should_not raise_error
    end

    it "should stop" do
      ->() { server.start; server.stop }.should_not raise_error
    end


  end
end
