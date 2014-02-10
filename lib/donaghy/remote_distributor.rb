require 'benchmark'

module Donaghy
  class RemoteDistributor
    include Logging

    attr_reader :evt
    def handle_distribution(evt)
      @evt = evt
      queues = matching_queue_names(evt.path)
      logger.info("RemoteDistributor: queues to publish #{evt.id}(#{evt.path}): #{queues.inspect}")
      queues.each do |queue|
        logger.info("sending #{evt.id}(#{evt.path}) to #{queue}")
        Donaghy.queue_for(queue).publish(evt)
      end
    end

    def matching_queue_names(path)
      logger.info("queue finder running for #{evt.id}(#{evt.path})")
      queue_and_class_name = nil
      queue_finder_time = Benchmark.realtime do
        queue_and_class_name = QueueFinder.new(path, Donaghy.storage).find
      end
      logger.info("queue finder finished running for #{evt.id}(#{evt.path}) in #{queue_finder_time}")
      names = if !queue_and_class_name.empty?
                queue_and_class_name.map{|obj| obj[:queue]}.uniq
              else
                []
              end
      names
    end
  end
end
