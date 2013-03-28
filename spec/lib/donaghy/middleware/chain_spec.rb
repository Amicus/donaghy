require 'spec_helper'

module Donaghy
  module Middleware
    describe Chain do

      subject { Chain.new }

      class FakeMiddlewareOne
        attr_reader :name, :marker
        def initialize(name, marker)
          @name = name
          @marker = marker
        end

        def call
          marker << [name, 'before']
          yield
          marker << [name, 'after']
        end
      end

      class FakeMiddlewareTwo < FakeMiddlewareOne; end

      it "should execute when nothing in the chain" do
        executed = false
        subject.execute do
          executed = true
        end
        executed.should be_true
      end

      it "should execute a chain in order" do
        marker = []
        executed = false
        subject.add(FakeMiddlewareOne, 'one', marker)
        subject.add(FakeMiddlewareTwo, 'two', marker)
        subject.execute do
          executed = true
        end
        executed.should be_true
        marker.should == [
            ['one', 'before'],
            ['two', 'before'],
            #here is where executed = true happened
            ['two', 'after'],
            ['one', 'after'],
        ]
      end

    end
  end
end
