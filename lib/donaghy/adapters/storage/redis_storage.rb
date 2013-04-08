require 'redis'

module Donaghy
  module Storage
    class RedisStorage

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      attr_reader :storage
      def initialize(opts = {})
        @storage = Redis.new(opts)
      end

      def flush
        storage.flushdb
      end

      def put(key, val)
        storage.set(key, val)
      end

      def get(key)
        storage.get(key)
      rescue Redis::CommandError => e
        if e.message =~ /Operation against a key holding the wrong kind of value/
          storage.smembers(key)
        else
          raise e
        end
      end

      def unset(key)
        storage.del(key)
      end

      def add_to_set(key, value)
        storage.sadd(key, value)
      end

      def remove_from_set(key, value)
        storage.srem(key, value)
      end

      def member_of?(key, value)
        storage.sismember(key, value)
      end

      def inc(key, val=1)
        storage.incrby(key,val)
      end

      def dec(key, val=1)
        storage.decrby(key,val)
      end

    end
  end
end
