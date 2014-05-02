module Donaghy
  module Middleware
    class Retry
      include Logging

      MAX_RETRY_ATTEMPTS = 200 # 15 minute max, so about 50 hours

      def call(event, _)
        yield
      rescue Exception => e
        event.retry_count += 1
        if event.retry_count > MAX_RETRY_ATTEMPTS
          logger.error("event #{event.id} failed over #{MAX_RETRY_ATTEMPTS} times")
          event.acknowledge
        elsif event.retry_count > 2 and Donaghy.storage.member_of?('kill_list', event.id)
          logger.error("event #{event.id} was killed due to a kill_list entry")
          event.acknowledge
        else
          Donaghy.storage.inc('retry', 1)
          event.requeue(delay: delay(event))
        end
        raise e
      end

      def delay(event)
        #this is kinda hacky, but SQS only supports a max of 15 minute timeouts right now
        [(800 + rand(100)), (event.retry_count^4) + 15 + (rand(30)*(event.retry_count+1))].min
      end
    end
  end
end
