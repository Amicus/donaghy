module Donaghy
  class RemoteDistributor
    include Logging

    def handle_distribution(evt)
      queue_names = matching_queue_names(evt.path)
      logger.info("RemoteDistributor: matching queues #{queue_names.inspect}")
      # if queue_names.empty? put in the "no one is listening" queue
      queue_names.each do |queue|
        logger.info("RemoteDistributor: sending #{evt.path} to #{queue}")
        Donaghy.queue_for(queue).publish(evt)
      end
    end

    def matching_queue_names(path)
      queue_and_class_name = QueueFinder.new(path, Donaghy.storage).find
      logger.info("RemoteDistributor: all queue and class names #{queue_and_class_name}")
      names = if !queue_and_class_name.empty?
                queue_and_class_name.map{|obj| obj[:queue]}.uniq
              else
                []
              end
      names
    end

  end
end
