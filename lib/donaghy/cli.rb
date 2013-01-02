require 'donaghy'

module Donaghy
  class CLI

    attr_reader :argv, :mutex, :interrupted
    def initialize(argv)
      @argv = argv
      @mutex = Mutex.new
      @interrupted = false
      load_config_if_there
    end

    def parse
      distribute_command
    end

    def load_config_if_there
      if argv.first == "-c"
        argv.shift
        file = argv.shift
        logger.info("CLI using config file: #{file}")
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
        when 'service_versions'
          $stdout.puts Marshal.load(Donaghy.zk.get("/donaghy/#{argv[0]}/#{argv[1]}").first)[:service_versions].inspect
        when 'run'
          logger.info("Received RUN from the CLI... starting up a server")
          run_server
        else
          raise ArgumentError, "Cannot understand argv: #{argv}"
      end
    end

    def run_server
      trap_exits
      begin
        logger.info 'Starting donaghy, hit Ctrl-C to stop'
        Donaghy.server.start
        logger.info 'server starting, sleeping until interrupt'
        sleep
      rescue Interrupt
        logger.info 'Shutting down'
        Donaghy.server.stop
        logger.info 'by bye'
        exit(0)
      end
    end

    def interrupt
      mutex.synchronize do
        unless @interrupted
          @interrupted = true
          Thread.main.raise Interrupt
        end
      end
    end

    def trap_exits
      #these are taken dirctly from sidekiq
      trap 'INT' do
        # Handle Ctrl-C in JRuby like MRI
        # http://jira.codehaus.org/browse/JRUBY-4637
        interrupt
      end

      trap 'TERM' do
        # Heroku sends TERM and then waits 10 seconds for process to exit.
        interrupt
      end
    end

    def console
      require 'pry'
      binding.pry
    end

    def logger
      Donaghy.logger
    end

  end
end
