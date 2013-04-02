module Donaghy
  module Middleware
    class Logging
      include Donaghy::Logging

      def call(handler, event)
        logger.info("handler #{handler.uid} beginning to work on #{event.id} for path #{event.path}")
        begin_time = Time.now
        yield
        end_time = Time.now
        logger.info("handler #{handler.uid} finished work on #{event.id} for path #{event.path}, took: #{length_of_time(begin_time, end_time)}")
      rescue Exception
        logger.error("handler #{handler.uid} FAILED working on #{event.id} for path #{event.path} at: #{length_of_time(begin_time, end_time)}")
        raise
      end

      def length_of_time(start, end_time)
        (end_time - start).to_f.round(4)
      end

    end
  end
end
