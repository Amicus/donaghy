module Donaghy
  module Middleware
    class Retry
      include Logging

      MAX_RETRY_ATTEMPTS = 25

      def call(event, _)
        yield
      rescue Exception => e
        event.retry_count += 1
        if event.retry_count > MAX_RETRY_ATTEMPTS
          logger.warn("event failed over #{MAX_RETRY_ATTEMPTS} times")
        else
          Donaghy.storage.inc('retry', 1)
          event.requeue(delay: delay(event))
        end
        raise e
      end

      def delay(event)
        #this is kinda hacky, but SQS only supports a max of 15 minute timeouts right now
        [900, (event.retry_count^4) + 15 + (rand(30)*(event.retry_count+1))].min
      end


    end
  end
end
