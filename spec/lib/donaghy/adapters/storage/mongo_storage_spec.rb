require 'spec_helper'

module Donaghy
  module Storage
    if defined?(Moped)
      describe MongoStorage do
        let(:key) { 'key' }

        it "flushes the storage" do
          subject.put(key, true)
          subject.flush
          expect(subject.get(key)).to be_nil
        end

        it "puts and gets the value from put" do
          subject.put(key, true)
          expect(subject.get(key)).to be_true
        end

        it "unsets" do
          subject.put(key, true)
          subject.unset(key)
          expect(subject.get(key)).to be_nil
        end

        it "allows an expires" do
          subject.put(key, 'test', 1)
          expect(subject.get(key)).to eq('test')
          sleep 1.001
          expect(subject.get(key)).to be_nil
        end

        describe "adding and removing from set" do
          before do
            subject.add_to_set(key, :a)
          end

          it "does not add duplicates to set" do
            subject.add_to_set('key', :a)
            expect(subject.get('key')).to eq([:a])
          end

          it "removes from set" do
            subject.add_to_set(key, :b)
            subject.remove_from_set(key, :a)
            expect(subject.get(key)).to eq([:b])
          end

        end

        describe "inc and dec" do
          before do
            subject.put(key, 1)
          end

          it "incs" do
            subject.inc(key, 1)
            expect(subject.get(key)).to eq(2)
          end

          it "decs" do
            subject.dec(key)
            expect(subject.get(key)).to eq(0)
          end

        end
      end
    end
  end
end
