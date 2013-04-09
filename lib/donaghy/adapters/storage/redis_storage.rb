require 'redis'
require 'connection_pool'

module Donaghy
  module Storage
    class RedisStorage

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      attr_reader :storage, :pool
      def initialize(opts = {})
        @opts = opts
        @pool = ConnectionPool.new(:size => 10, :timeout => 5) { Redis.new(@opts) }
        #@storage = Redis.new(opts)
      end

      def flush
        pool.with {|storage| storage.flushdb }
      end

      def put(key, val, expires=nil)
        pool.with do |storage|
          case val
            when Integer, String
              storage.set(key, val)
            else
              storage.set(key, Marshal.dump(val))
          end
          storage.expire(key, expires.to_i) if expires
        end
      end

      def get(key)
        val = pool.with {|storage| storage.get(key) }
        if val
          Marshal.load(val)
        end
      rescue Redis::CommandError => e
        if e.message =~ /Operation against a key holding the wrong kind of value/
          val = pool.with {|storage| storage.smembers(key) }
          if val
            val.map {|v| Marshal.load(v)}
          end
        else
          raise e
        end
      rescue ArgumentError, TypeError
        val
      end

      def unset(key)
        pool.with {|storage| storage.del(key) }
      end

      def add_to_set(key, value)
        pool.with {|storage| storage.sadd(key, Marshal.dump(value)) }
      end

      def remove_from_set(key, value)
        pool.with {|storage| storage.srem(key, Marshal.dump(value)) }
      end

      # redis.sismember doesn't work here for some reason
      def member_of?(key, value)
        val = get(key)
        val and val.include?(value)
      end

      def inc(key, val=1)
        pool.with {|storage| storage.incrby(key,val) }
      end

      def dec(key, val=1)
        pool.with {|storage| storage.decrby(key,val) }
      end

    end
  end
end
