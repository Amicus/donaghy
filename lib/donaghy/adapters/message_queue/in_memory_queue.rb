require 'redis'

# Redis is intended for local development only at this point as it can lose messages
# and doesn't handle retries correctly
module Donaghy
  module MessageQueue
    class InMemoryQueue
      include Logging

      class ArrayQueue

        attr_reader :queue, :queue_name, :opts
        def initialize(queue_name, opts = {})
          @opts = opts
          @queue = []
          @guard = Mutex.new
          @queue_name = queue_name
        end

        def name
          queue_name
        end

        def publish(evt, opts={})
          @guard.synchronize do
            queue << evt
          end
        end

        def receive
          @guard.synchronize do
            queue.shift
          end
        end

        def destroy
          @guard.synchronize do
            @queue = []
          end
        end

        def exists?
          true
        end

        def length
          queue.length
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
        ArrayQueue.new(queue_name, redis_opts: opts)
      end

    end
  end
end
