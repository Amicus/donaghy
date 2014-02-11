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
          @queue = ::Queue.new
          @queue_name = queue_name
        end

        def name
          queue_name
        end

        def publish(evt, opts={})
          queue.push(evt.to_json)
        end

        def receive
          Timeout.timeout(5) do
            msg = queue.pop
            Event.from_json(msg) if msg
          end
        rescue Timeout::Error
          nil
        end

        def destroy
          queue.clear
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

      attr_reader :opts, :queue_hash, :guard
      def initialize(opts = {})
        @guard = Mutex.new
        @queue_hash = {}
        @opts = opts
      end

      def find_by_name(queue_name)
        if queue_hash[queue_name]
          queue_hash[queue_name]
        else
          guard.synchronize do
            return queue_hash[queue_name] if queue_hash[queue_name]
            queue_hash[queue_name] = ArrayQueue.new(queue_name, redis_opts: opts)
          end
        end
      end

      def destroy_by_name(queue_name)
        guard.synchronize do
          if queue = queue_hash[queue_name]
            queue_hash.delete(queue_name)
            queue.destroy
          end
        end
      end

    end
  end
end
