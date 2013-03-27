module Donaghy
  module Storage

    class Abstract

      attr_reader :storage_hash, :lock
        def initialize
        end

        def flush!
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
    end

  end

end
