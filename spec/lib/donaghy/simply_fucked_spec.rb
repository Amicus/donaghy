require 'spec_helper'

describe "a fucked situation" do


  class SimpleQueue

    def initialize
      @queue = Queue.new
    end

    def publish(evt)
      @queue.push(evt)
    end

    def receive
      sleep 1
      @queue.pop(true) #non block
    rescue ThreadError
      nil
    end

  end


  SIMPLE_QUEUE = SimpleQueue.new


  class SimpleHandler
    include Celluloid

    def initialize(manager)
      @manager = manager
    end

    def handle_result(result)
      @manager.async.handler_done(current_actor, result)
    end

  end


  class SimpleFetcher
    include Celluloid

    def initialize(manager, queue, opts = {})
      @manager = manager
      @queue = queue
    end

    def fetch
      res = @queue.receive
      if res
        @manager.async.handle_result(res)
      else
        after(0) { fetch if !@stopped and @manager.alive? } if !@stopped and @manager.alive?
      end
    end

    def terminate
      @stopped = true
      super
    end

  end

  class SimpleManager
    include Celluloid

    trap_exit :handler_died

    def initialize(queue, holder, opts={})
      @holder = holder
      @queue = queue
      @fetcher = SimpleFetcher.new(current_actor, @queue)
      @concurrency = opts[:concurrency] || Celluloid.ncores
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
      @fetcher.async.fetch unless @stopped
    end

    def handle_result(result)
      unless @stopped
        handler = @available.shift
        @busy << handler
        handler.async.handle_result(result)
      end
    end

    def handler_died(handler, reason)
      Celluloid.logger.info("handler died for #{reason}")
      @busy.delete(handler)
      unless @stopped
        @available << SimpleHandler.new_link(current_actor)
      end
    end

    def terminate
      @stopped = true
      @fetcher.terminate
      (@available + @busy).each(&:terminate)
      super()
    end

    def stop
      terminate
    end

  end


  let(:queue) { SIMPLE_QUEUE }
  let(:holder) { Queue.new }
  let(:manager) { SimpleManager.new(queue, holder, concurrency: 5) }

  before do
    manager.start
  end

  after do
    manager.stop
  end

  it "should publish a message" do
    queue.publish("result")
    Timeout.timeout(2) do
      holder.pop.should == 'result'
    end
  end

  it "should publish the message the second time" do
    queue.publish("result")
    Timeout.timeout(2) do
      holder.pop.should == 'result'
    end
  end

  it "should publish the message the third time" do
    queue.publish("result")
    Timeout.timeout(2) do
      holder.pop.should == 'result'
    end
  end

end
