require 'spec_helper'
require 'redis'

describe "a fucked situation" do


  class SimpleQueue

    QUEUE_NAME = 'simple_queue'

    def initialize
      @queue = Redis.new
    end

    def publish(str)
      Donaghy.logger.info("publishing: #{str}")
      @queue.rpush(QUEUE_NAME, str)
    end

    def receive
      receiver = Redis.new
      res = receiver.blpop(QUEUE_NAME, timeout: 1)
      Donaghy.logger.info("blpop got #{res}")
      res[1] if res
    ensure
      receiver.quit if receiver
    end

  end

  SIMPLE_QUEUE = SimpleQueue.new

  class SimpleHandler
    include Celluloid

    def initialize(manager)
      @manager = manager
    end

    def handle_result(result)
      Donaghy.logger.info("handling: #{result}")
      @manager.async.handler_done(current_actor, result)
    end

  end


  class SimpleFetcher
    include Celluloid
    finalizer :cleanup


    def initialize(manager, queue)
      @manager = manager
      @queue = queue
      #@receiver = Receiver.new_link(queue)
    end

    def fetch
      return if @done
      Donaghy.logger.info("fetch started")
      res = @queue.receive

      if done?
        Donaghy.logger.info("in the real thing, we'd requeue")
      else
        if res
          @manager.async.handle_result(res)
        else
          after(0) { fetch }
        end
      end
    end

    def done?
      !@manager.alive? or @done
    end

    def cleanup
      @done = true
    end


  end

  class SimpleManager
    include Celluloid

    trap_exit :handler_died

    def initialize(queue, holder, opts={})
      @holder = holder
      @queue = queue
      @concurrency = opts[:concurrency] || Celluloid.ncores

      @fetcher = SimpleFetcher.new(current_actor, @queue)

      @available = @concurrency.times.map do
        SimpleHandler.new_link(current_actor)
      end
      @busy = []
    end

    def start
      @stopped = false
      assign_work
    end

    def handler_done(handler, res)
      @holder.push(res)
      Celluloid.logger.info("handler finished work")
      @busy.delete(handler)
      @available << handler
      assign_work
    end

    def assign_work
      Donaghy.logger.info("assign work called")
      @fetcher.async.fetch unless @stopped
    end

    def handle_result(result)
      unless @stopped
        Donaghy.logger.info("handle result")
        Donaghy.logger.info("result is: #{result}")
        if result
          Donaghy.logger.info("sending: #{result} to handler")
          handler = @available.shift
          @busy << handler
          handler.async.handle_result(result)
        end
        assign_work
      end
    end

    def handler_died(handler, reason)
      Celluloid.logger.info("handler died for #{reason}")
      @busy.delete(handler)
      unless @stopped
        @available << SimpleHandler.new_link(current_actor)
        assign_work
      end
    end

    def terminate
      @stopped = true
      @fetcher.terminate
      (@available + @busy).each(&:terminate)
      super()
    end

    def stop
      Donaghy.logger.info("stop received")
      terminate
    end

  end


  let(:queue) { SIMPLE_QUEUE }
  let(:holder) { Queue.new }
  let(:manager) { SimpleManager.new(queue, holder, concurrency: 5) }
  let(:spec_redis) { Redis.new }

  before do
    spec_redis.del(SimpleQueue::QUEUE_NAME)
    manager.start
  end

  after do
    manager.stop
    spec_redis.quit
  end

  it "should publish a message" do
    queue.publish("result")
    Timeout.timeout(3) do
      holder.pop.should == 'result'
    end
  end

  it "should publish a message second time" do
    queue.publish("result")
    Timeout.timeout(3) do
      holder.pop.should == 'result'
    end
  end

end
