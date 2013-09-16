module Donaghy
  class EventPublisher
    include Donaghy::Service

    alias_method :trigger, :root_trigger

  end
end
