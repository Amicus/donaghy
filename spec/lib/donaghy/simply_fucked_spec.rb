require 'spec_helper'
require 'redis'

describe "a fucked situation" do


  class SimpleQueue

    QUEUE_NAME = 'simple_queue'

    def initialize
      @queue = Redis.new
    end

    def publish(evt)
      Donaghy.logger.info("publishing: #{evt}")
      @queue.rpush(QUEUE_NAME, evt)
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

    #task_class TaskThread

    def initialize(manager, queue)
      @manager = manager
      @queue = queue
    end

    def fetch
      Donaghy.logger.info("fetch started")
      res = @queue.receive
      Donaghy.logger.info("fetch received: #{res}")
      res
    end

  end

  class SimpleManager
    include Celluloid

    trap_exit :handler_died

    def initialize(queue, holder, opts={})
      @holder = holder
      @queue = queue
      @concurrency = opts[:concurrency] || Celluloid.ncores

      @fetcher = SimpleFetcher.pool(size: @concurrency, args: [current_actor, @queue])

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
      async.handle_result(@fetcher.fetch) unless @stopped
    end

    def handle_result(result)
      unless @stopped
        if result
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

  $redis = Redis.new

  before do
    $redis.del(SimpleQueue::QUEUE_NAME)
    manager.start
  end

  after do
    manager.stop
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
