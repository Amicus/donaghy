module Donaghy

  #   Sidekiq::Client.push('queue' => 'my_queue', 'class' => MyWorker, 'args' => ['foo', 1, :bat => 'bar'])


  class EventDistributerWorker
    include Sidekiq::Worker

    def perform(path, event_hash)
      queues_and_classes = QueueFinder.new(path).find
      queues_and_classes.each do |queue_and_class|
        Sidekiq.push('queue' => queue_and_class[:queue], 'class' => queue_and_class[:klass], 'args' => event_hash)
      end
    end


  end

end
