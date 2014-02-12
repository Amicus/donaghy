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
        transaction_mode = (opts[:transaction_mode] || :transactional).to_sym
        @storage = TorqueBox::Infinispan::Cache.new({
            name: name,
            mode: mode,
            locking_mode: locking_mode,
            transaction_mode: transaction_mode
        })
      end

      def flush
        storage.clear
      end

      def put(key, val, expires=0)
        storage.put(key, val, expires)
      end

      def get(key, event=nil)
        storage.get(key)
      end

      def unset(key)
        storage.remove(key)
      end

      def add_to_set(key, value)
        execute_in_transaction do
          current_value = get(key)
          if current_value and !(current_value.respond_to?(:uniq) or current_value.respond_to?(:push))
            Donaghy.logger.error "TorqueboxStorage: expected an enumerable at key #{key}, but was: #{current_value.inspect}, unset #{key}"
            unset(key)
            current_value = []
          else
            arry = current_value || []
            arry.push(value)
            put(key, arry.uniq)
          end
        end
      end

      def remove_from_set(key, value)
        execute_in_transaction do
          arry = get(key) || []
          put(key, (arry - Array(value)))
        end
      end

      def member_of?(key, value)
        get(key).include?(value)
      end

      def inc(key, val=1)
        put(key, get(key).to_i) if get(key).is_a?(String)
        storage.increment(key, val)
      end

      def dec(key, val=1)
        put(key, get(key).to_i) if get(key).is_a?(String)
        storage.decrement(key, val)
      end

      def execute_in_transaction
        storage.transaction do
          yield
        end
      end

    end
  end
end
