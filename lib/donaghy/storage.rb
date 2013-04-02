module Donaghy
  module Storage
    class Abstract
      def initialize
      end

      def flush
      end

      def put(key, val)
      end

      def get(key)
      end

      def add_to_set(key, value)
      end

      def unset(key)
      end

      def remove_from_set(key, value)
      end

      def inc(key)
      end

      def dec(key)
      end

      def member_of?(key, value)
      end

    end
  end
end
