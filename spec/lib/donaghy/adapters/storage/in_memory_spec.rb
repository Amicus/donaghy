require 'spec_helper'
require 'donaghy/adapters/storage/in_memory'


module Donaghy
  module Storage
    describe InMemory do

       it "should put and get" do
         subject.put('cool', true)
         subject.get('cool').should be_true
       end

       it "should add to set" do
         subject.add_to_set('key', :a)
         subject.add_to_set('key', :a)
         subject.get('key').should == [:a]
       end

    end
  end
end
