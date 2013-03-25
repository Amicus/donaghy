require 'hashie/mash'

module Donaghy
  module Storage
    class InMemory

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      attr_reader :storage_hash
      def initialize
        @storage_hash = Hashie::Mash.new
      end

      def flush!
        @storage_hash = Hashie::Mash.new
      end

      def put(key, val)
        @storage_hash[key] = val
      end

      def get(key)
        @storage_hash[key]
      end

      def add_to_set(key, value)
        if get(key) and !(get(key).respond_to?(:uniq) or get(key).respond_to?(:push))
          raise NotAnEnumerableError
        end
        arry = get(key) || []
        put(key, arry.push(value).uniq)
      end

      def unset(key)
        storage_hash.delete(key)
      end

      def remove_from_set(key, value)
        storage_hash(key).delete(value)
      end

      def inc(key)
        raise NotAnIntegerError if get(key) && !get(key).is_a?(Integer)
        if get(key)
          put(key, get(key) + 1)
        else
          put(key, 1)
        end
      end

    end
  end
end
