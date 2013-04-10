module Donaghy
  class ListenerSerializer

    def self.dump(hsh)
      "#{hsh[:queue]},#{hsh[:class_name]}"
    end

    # message_queue, klass = ListenerSerializer.load("my_queue,MyClass")
    def self.load(str)
      split = str.split(",")
      {queue: split[0], class_name: split[1]}
    end

  end
end
