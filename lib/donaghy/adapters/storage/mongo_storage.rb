require 'moped'

module Donaghy
  module Storage
    class MongoStorage

      DEFAULT_HOSTS = [ "127.0.0.1:27017" ]
      DEFAULT_DATABASE = "#{Donaghy.donaghy_env}_donaghy"
      DEFAULT_COLLECTION = 'donaghy'

      attr_reader :session, :opts, :collection
      def initialize(opts = {})
        @opts = opts
        @session = Moped::Session.new((opts[:hosts] || DEFAULT_HOSTS), {
            safe: opts[:safe],
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
        query_for_key(key).upsert({:$set => {_id: key}})
        query_for_key(key).one
      end

    end
  end
end
