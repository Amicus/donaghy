require 'spec_helper'
require 'donaghy/adapters/storage/in_memory'


module Donaghy
  module Storage
    describe InMemory do
      let(:key) { 'key' }

      it "should flush" do
        subject.put(key, true)
        subject.flush
        subject.get(key).should be_nil
      end

      it "should put and get" do
        subject.put(key, true)
        subject.get(key).should be_true
      end

      it "should unset" do
        subject.put(key, true)
        subject.unset(key)
        subject.get(key).should be_nil
      end

      it "should allow an expires" do
        now = Time.now
        subject.put(key, 'test', 10)
        subject.get(key).should == 'test'
        Timecop.freeze(now + 11) do
          subject.get(key).should be_nil
        end
      end

      describe "adding and removing from set" do
        before do
          subject.add_to_set(key, :a)
        end

        it "should add to set" do
          subject.add_to_set('key', :a)
          subject.get('key').should == [:a]
        end

        it "should remove from set" do
          subject.add_to_set(key, :b)
          subject.remove_from_set(key, :a)
          subject.get(key).should == [:b]
        end

      end

      describe "inc and dec" do
        before do
          subject.put(key, 1)
        end

        it "should inc" do
          subject.inc(key, 1)
          subject.get(key).should == 2
        end

        it "should dec" do
          subject.dec(key)
          subject.get(key).should == 0
        end

      end
    end
  end
end
