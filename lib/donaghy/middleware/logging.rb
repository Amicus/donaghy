module Donaghy
  module Middleware
    class Logging
      include Donaghy::Logging

      def call(event, handler_info)
        logger.info("handler #{handler_info[:uid]} beginning to work on #{event.id} for path #{event.path}")
        begin_time = Time.now
        yield
        end_time = Time.now
        logger.info("handler #{handler_info[:uid]} finished work on #{event.id} for path #{event.path}, took: #{length_of_time(begin_time, end_time)}")
      rescue Exception => e
        logger.error("handler #{handler_info[:uid]} FAILED working on #{event.id} for path #{event.path} with #{e.class}")
        raise e
      end

      def length_of_time(start_time, end_time)
        (end_time - start_time).to_f.round(4)
      end

    end
  end
end
