module Donaghy
  module Middleware
    class Stats

      def call(handler, event)
        Donaghy.storage.inc('inprogress_count')
        Donaghy.storage.add_to_set('inprogress', event.id)
        Donaghy.storage.put("inprogerss:#{event.id}", event.to_json)

        yield

        Donaghy.storage.inc('complete', 1)
        Donaghy.storage.unset("failure:#{event.id}")
        Donaghy.storage.remove_from_set('failures', event.id)

      rescue Exception => e
        Donaghy.storage.inc('failed', 1)
        Donaghy.storage.add_to_set('failures', event.id)
        Donaghy.storage.put("failure:#{event.id}", JSON.dump({
            event: event.to_hash(without: [:received_on]),
            exception: e.class.to_s,
            exception_inspect: e.inspect,
            backtrace: e.backtrace,
        }))

        raise e
      ensure
        Donaghy.storage.remove_from_set('inprogress', event.id)
        Donaghy.storage.unset("inprogress:#{event.id}")
        Donaghy.storage.dec('inprogress_count')
      end

    end
  end
end
