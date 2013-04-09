require 'redis'
require 'connection_pool'

# Redis is intended for local development only at this point as it can lose messages
# and doesn't handle retries correctly
module Donaghy
  module MessageQueue
    class RedisQueue
      include Logging

      class RedisListQueue

        attr_reader :queue, :queue_name, :opts, :redis, :pool
        def initialize(queue_name, opts = {})
          @opts = opts
          @pool = ConnectionPool.new(:size => 10, :timeout => 5) do
            Redis.new(opts[:redis_opts])
          end
          #@redis = Redis.new(opts[:redis_opts])
          @queue_name = queue_name
        end

        def name
          queue_name
        end

        def publish(evt, opts={})
          pool.with {|redis| redis.rpush(queue_name, evt.to_json) }
        end

        def receive
          #do a new redis here as blpop blocks all other connections
          redis = Redis.new(opts[:redis_opts])
          message = redis.blpop(queue_name, timeout: (opts[:wait_time_seconds] || 5))
          return Event.from_json(message[1]) if message and !message.empty?
        ensure
          redis.quit if redis
        end

        def destroy
          pool.with {|redis| redis.del(queue_name) }
        end

        def exists?
          pool.with {|redis| redis.exists(queue_name) }
        end

        def length
          pool.with {|redis| redis.llen(queue_name) }
        end

        def length_of_delayed
          0
        end

      end

      attr_reader :opts
      def initialize(opts = {})
        @opts = opts
      end

      def find_by_name(queue_name)
        RedisListQueue.new(queue_name, redis_opts: opts)
      end

    end
  end
end
