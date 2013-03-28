module Donaghy
  module Middleware
    class Stats

      def call(handler, event)
        Donaghy.storage.inc('inprogress', 1)
        yield
        Donaghy.storage.inc('complete', 1)
        Donaghy.storage.dec('inprogress', 1)
      end

    end
  end
end
