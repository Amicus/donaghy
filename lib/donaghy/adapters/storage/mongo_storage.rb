require 'moped'
require 'active_support/core_ext/module/delegation'

module Donaghy
  module Storage
    class MongoStorage

      delegate :flush, :put, :get, :unset, :add_to_set,
               :remove_from_set, :member_of?, :inc, :dec,
        to: :connection_pool

      attr_reader :connection_pool, :pool_size
      def initialize(opts = {})
        @pool_size = opts[:pool_size] || default_pool_size
        @connection_pool = MongoStorageActor.pool(size: pool_size, args: [opts])
      end

      def disconnect
        connection_pool.terminate
      end

      # in an investigation concluding 2/13/2014 we found that a very high number of actors
      # in the pool here resulted in a very high wait time for an actor. Seems to be related
      # to the number of cores in your system as we could replicate thrashing (slowdown) on staging
      # with 20 concurrent threads (2 cores) and on a macbook pro (8 cores) with 80 threads
      def default_pool_size
        [Celluloid.cores * 4, Donaghy.configuration[:concurrency] + Donaghy.configuration[:cluster_concurrency]].min
      end

      class MongoStorageActor
        include Celluloid

        finalizer :disconnect

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
          collection.find.remove_all
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
          if document and !document_expired?(document)
            document['val']
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

        def disconnect
          session.disconnect
        end

      private
        def query_for_key(key)
          collection.find(_id: key)
        end

        def document_for_key(key)
          key = query_for_key(key).one
          # we have to do this weird :$set here because if we do not then
          # it assumes we are trying to upsert the document to nil
          # (overwriting all keys). This lets it keep the document as it
          # exists
          key || query_for_key(key).upsert({:$set => {}})
        end

        def document_expired?(document)
          document['expires'] and document['expires'] < Time.now
        end
      end
    end
  end
end
