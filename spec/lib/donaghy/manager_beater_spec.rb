require 'spec_helper'
require 'donaghy/manager_beater'

require 'active_support/core_ext/hash/keys'

module Donaghy

  describe ManagerBeater do

    subject { ManagerBeater.new("test", 5) }
    let!(:path) { subject.path_to_beat }

    after do
      subject.terminate if subject.alive?
    end

    it "should beat the hostname and name path" do
      subject.path_to_beat.should == "donaghy_#{Donaghy.hostname}_test"
    end

    describe "start_beating" do
      before do
        subject.start_beating
      end

      it "sets the configuration" do
        subject.start_beating
        expect(storage.get(subject.path_to_beat).to_json).to eq(Donaghy.configuration.to_hash.to_json)
      end

      it "should add the current hostname to the donaghy hosts" do
        storage.member_of?('donaghy_hosts', Donaghy.hostname).should be_true
      end

      it "should add the individaul service to the host" do
        storage.member_of?("donaghy_#{Donaghy.hostname}", path).should be_true
      end

    end

    describe "on termination" do

      before do
        subject.terminate
      end

      it "should remove the individual service from the host" do
        storage.member_of?("donaghy_#{Donaghy.hostname}", path).should be_false
      end

      it "should remove the configuration" do
        storage.get(path).should be_nil
      end

    end

    def storage
      Donaghy.storage
    end
  end
end
