require 'hashie/mash'

module Donaghy
  module Storage
    class InMemory

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      attr_reader :storage_hash, :lock
      def initialize
        @storage_hash = Hashie::Mash.new
        @lock = Mutex.new
      end

      def flush!
        @storage_hash = Hashie::Mash.new
      end

      def put(key, val)
        storage_hash[key] = val
      end

      def get(key)
        storage_hash[key]
      end

      def add_to_set(key, value)
        if get(key) and !(get(key).respond_to?(:uniq) or get(key).respond_to?(:push))
          raise NotAnEnumerableError
        end
        lock.synchronize do
          arry = get(key) || []
          arry.push(value)
          put(key, arry)
        end
      end

      def unset(key)
        lock.synchronize do
          storage_hash.delete(key)
        end
      end

      def remove_from_set(key, value)
        lock.synchronize do
          get(key).delete(value)
        end
      end

      def inc(key)
        raise NotAnIntegerError if get(key) && !get(key).is_a?(Integer)
        lock.synchronize do
          if get(key)
            put(key, get(key) + 1)
          else
            put(key, 1)
          end
        end
      end

      def dec(key)
        raise NotAnIntegerError if get(key) && !get(key).is_a?(Integer)
        lock.synchronize do
          if get(key)
            put(key, get(key) - 1)
          else
            put(key, 0)
          end
        end
      end

    end
  end
end