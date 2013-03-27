module Donaghy

  # The ClusterNode will spin this up and assign the right receives on it and then the regular system should take care
  # of giving it to this guy to proxy out to an already defined worker's perform method
  class SidekiqRunner
    include Donaghy::Service

    attr_reader :event

    def handle_perform(event)
      @event = event
      klass = class_name.camelize.constantize
      klass.new.perform(*event.payload.args)
    end

  private

    def class_name
      event.path.sub("#{Donaghy.root_event_path}/#{Service::SIDEKIQ_EVENT_PREFIX}", '')
    end


  end
end
