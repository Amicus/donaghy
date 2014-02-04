require 'moped'
require 'active_support/core_ext/module/delegation'

module Donaghy
  module Storage
    class MongoStorage

      delegate :flush, :put, :get, :unset, :add_to_set, :remove_from_set, :member_of?, :inc, :dec, to: :connection_pool

      attr_reader :connection_pool
      def initialize(opts = {})
        @connection_pool = MongoStorageActor.pool(size: concurrency, args: [opts])
      end

      def concurrency
        Donaghy.configuration[:concurrency] + Donaghy.configuration[:cluster_concurrency]
      end

      class MongoStorageActor
        include Celluloid

        DEFAULT_HOSTS = [ "127.0.0.1:27017" ]
        DEFAULT_DATABASE = "#{Donaghy.donaghy_env}_donaghy"
        DEFAULT_COLLECTION = 'donaghy'

        attr_reader :session, :opts, :collection
        def initialize(opts = {})
          @opts = opts
          safe = opts[:safe] == nil ? true : opts[:safe]
          @session = Moped::Session.new((opts[:hosts] || DEFAULT_HOSTS), {
              safe: safe,
              database: opts[:database] || DEFAULT_DATABASE,
              consistency: opts[:consistency] || :strong
          })
          @collection = @session[opts[:collection] || DEFAULT_COLLECTION]
        end

        def flush
          session.drop
        end

        def put(key, val, expires=nil)

          upsert_doc = { :$set => { val: val } }
          if expires
            upsert_doc[:$set].merge!(expires: Time.now + expires)
          else
            upsert_doc.merge!(:$unset => {expires: 1 })
          end
          query_for_key(key).upsert(upsert_doc)
        end

        def get(key)
          document = document_for_key(key)
          if document
            document['val'] if !document['expires'] or document['expires'] >= Time.now
          end
        end

        def unset(key)
          query_for_key(key).remove
        end

        def add_to_set(key, value)
          query_for_key(key).upsert(:$addToSet => { val: value })
        end

        def remove_from_set(key, value)
          query_for_key(key).update(:$pull => { val: value })
        end

        # redis.sismember doesn't work here for some reason
        def member_of?(key, value)
          document = document_for_key(key)
          if document
            Array(document['val']).include?(value)
          end
        end

        def inc(key, val=1)
          query_for_key(key).upsert(:$inc => { val: val })
        end

        def dec(key, val=1)
          query_for_key(key).upsert(:$inc => { val: -1*val })
        end

      private
        def query_for_key(key)
          collection.find(_id: key)
        end

        def document_for_key(key)
          query_for_key(key).upsert({:$set => {}})
          query_for_key(key).one
        end
      end
    end
  end
end
