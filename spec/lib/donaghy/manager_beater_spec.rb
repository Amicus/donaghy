require 'spec_helper'
require 'donaghy/manager_beater'

module Donaghy

  describe ManagerBeater do

    subject { ManagerBeater.new("test", 5) }

    after do
      subject.terminate if subject.alive?
    end

    it "should beat the hostname and name path" do
      subject.path_to_beat.should == "#{Donaghy.hostname}_test"
    end

    it "should set the configuration" do
      subject.beat
      Donaghy.storage.get(subject.path_to_beat).should == Donaghy.configuration.to_hash
    end

  end

end
