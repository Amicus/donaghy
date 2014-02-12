require 'hashie/mash'

module Donaghy
  module Storage
    class InMemory

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      class ValueEntry

        attr_accessor :value, :expires
        def initialize(attrs={})
          @value = attrs[:value]
          @expires = attrs[:expires]
        end
      end

      attr_reader :storage_hash, :lock
      def initialize
        @storage_hash = Hashie::Mash.new
        @lock = Mutex.new
      end

      def flush
        @storage_hash = Hashie::Mash.new
      end

      def put(key, val, expires=nil)
        if expires
          expires = Time.now + expires
        end
        entry = ValueEntry.new(value: val, expires: expires)
        storage_hash[key] = entry
      end

      def get(key, event=nil)
        entry = storage_hash[key]
        if entry and (!entry.expires || entry.expires > Time.now)
          entry.value
        end
      end

      def unset(key)
        lock.synchronize do
          storage_hash.delete(key)
        end
      end

      def add_to_set(key, value)
        if get(key) and !(get(key).respond_to?(:uniq) or get(key).respond_to?(:push))
          raise NotAnEnumerableError
        end
        lock.synchronize do
          arry = get(key) || []
          arry.push(value)
          put(key, arry.uniq)
        end
      end

      def remove_from_set(key, value)
        lock.synchronize do
          arry = get(key) || []
          put(key, (arry - Array(value)))
        end
      end

      def member_of?(key, value)
        Array(get(key)).include?(value)
      end

      def inc(key, val=1)
        raise NotAnIntegerError if get(key) && !get(key).is_a?(Integer)
        lock.synchronize do
          if get(key)
            put(key, get(key) + val)
          else
            put(key, val)
          end
        end
      end

      def dec(key, val=1)
        raise NotAnIntegerError if get(key) && !get(key).is_a?(Integer)
        lock.synchronize do
          if get(key)
            put(key, get(key) - val)
          else
            put(key, val)
          end
        end
      end

    end
  end
end
