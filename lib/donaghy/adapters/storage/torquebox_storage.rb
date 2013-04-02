require 'torquebox-cache'

module Donaghy
  module Storage
    class TorqueboxStorage

      class NotAnIntegerError < StandardError; end
      class NotAnEnumerableError < StandardError; end

      attr_reader :storage
      def initialize(opts = {})
        name = opts[:name] || 'donaghy'
        mode = (opts[:mode] || :replicated).to_sym
        # maybe we want to make this optimistic, but for now we have a limited boxes and no real performance
        # issues. Ideally we'd like to not use transactions
        locking_mode = (opts[:locking_mode] || :pessimistic).to_sym
        @storage = TorqueBox::Infinispan::Cache.new(name: name, mode: mode, locking_mode: locking_mode)
      end

      def flush
        storage.clear
      end

      def put(key, val)
        storage.put(key, val)
      end

      def get(key)
        storage.get(key)
      end

      def unset(key)
        storage.remove(key)
      end

      def add_to_set(key, value)
        storage.transaction do
          current_value = get(key)
          if current_value and !(current_value.respond_to?(:uniq) or current_value.respond_to?(:push))
            raise NotAnEnumerableError
          else
            arry = current_value || []
            arry.push(value)
            put(key, arry.uniq)
          end
        end
      end

      def remove_from_set(key, value)
        storage.transaction do
          arry = get(key) || []
          put(key, (arry - Array(value)))
        end
      end

      def inc(key, val=1)
        storage.transaction do
          @storage.increment(key, val)
        end
      end

      def dec(key, val=1)
        storage.transaction do
          storage.decrement(key, val)
        end
      end

    end
  end
end