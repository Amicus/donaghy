require 'redis'

module Donaghy
  module MessageQueue
    class RedisQueue
      include Logging

      class RedisListQueue

        attr_reader :queue, :queue_name, :opts, :redis
        def initialize(queue_name, opts = {})
          @opts = opts
          @redis = Redis.new(opts[:redis_opts])
          @queue_name = queue_name
        end

        def name
          queue_name
        end

        def publish(evt, opts={})
          redis.rpush(queue_name, evt.to_json)
        end

        def receive
          #do a new redis here as blpop blocks all other connections
          message = Redis.new(opts[:redis_opts]).blpop(queue_name, timeout: (opts[:wait_time_seconds] || 5))
          Event.from_json(message[1]) if message and !message.empty?
        end

        def destroy
          redis.del(queue_name)
        end

        def exists?
          redis.exists(queue_name)
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
