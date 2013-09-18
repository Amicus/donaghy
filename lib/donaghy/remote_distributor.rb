module Donaghy
  class RemoteDistributor
    include Logging

    def handle_distribution(evt)
      matching_queue_names(evt.path).each do |queue|
        logger.info("sending #{evt.path} to #{queue}")
        Donaghy.queue_for(queue).publish(evt)
      end
    end
    def matching_queue_names(path)
      queue_and_class_name = QueueFinder.new(path, Donaghy.storage).find
      names = if !queue_and_class_name.empty?
                queue_and_class_name.map{|obj| obj[:queue]}.uniq
              else
                logger.info("no matching queues for #{path}")
                []
              end
      names
    end
  end
end
