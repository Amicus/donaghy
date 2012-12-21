require 'donaghy'
require 'pry'

module Donaghy
  class CLI

    attr_reader :argv
    def initialize(argv)
      @argv = argv
      load_config_if_there
      distribute_command
    end

    def load_config_if_there
      if argv.first == "-c"
        argv.shift
        file = argv.shift
        Donaghy.configuration = {config_file: file}
      end
    end

    def distribute_command
      command = argv.shift
      case command
        when 'console'
          console
        when 'publish'
          Donaghy.event_publisher.root_trigger(argv[0], payload: argv[1])
        when 'listall'
          $stdout.puts Donaghy::QueueFinder.all_listeners.inspect
        else
          raise ArgumentError, "Cannot understand argv"
      end
    end

    def console
      binding.pry
    end

  end
end
