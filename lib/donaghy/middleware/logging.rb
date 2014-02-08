module Donaghy
  module Middleware
    class Logging
      include Donaghy::Logging

      def call(event, handler_info)
        logger.info("HANDLER #{handler_info[:uid]} STARTED #{event.id}(#{event.path}) event: #{event.inspect}")
        begin_time = Time.now
        yield
        end_time = Time.now
        logger.info("HANDLER #{handler_info[:uid]} COMPLETE #{event.id}(#{event.path}) time: #{length_of_time(begin_time, end_time)}")
      rescue Exception => e
        logger.error("HANDLER #{handler_info[:uid]} FAILED #{event.id}(#{event.path}) error: #{e.class}, #{e.backtrace.join(':::')}")
        raise e
      end

      def length_of_time(start_time, end_time)
        (end_time - start_time).to_f.round(4)
      end

    end
  end
end
