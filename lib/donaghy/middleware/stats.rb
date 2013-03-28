module Donaghy
  module Middleware
    class Stats

      def call(handler, event)
        yield
      end


    end
  end
end
