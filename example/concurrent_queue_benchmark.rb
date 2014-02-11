require 'benchmark'
require 'donaghy/adapters/message_queue/sqs'

SQS = Donaghy::MessageQueue::Sqs.new()

SQS.send(:sqs).config.http_handler.pool.size

TIME_QUEUE = Queue.new

class SessionActor
  include Celluloid

  def initialize(queue = nil)
    @queue = queue || SQS.find_by_name('topper')
  end

  def publish(some_message = {})
    # uncomment the below to plan around with starting with a clean
    # pool for every publish
    #AWS.config.http_handler.pool.clean!
    TIME_QUEUE << Benchmark.realtime { @queue.publish(some_message) }
  end
end

TIMES_TO_TRY = 500

q = SQS.find_by_name('topper')

pool = SessionActor.pool(size: TIMES_TO_TRY, args: [q])

Thread.new do
  queue.receive_message(wait_time_seconds: 15)
end

TIMES_TO_TRY.times do
  pool.async.publish({bob: true})
end

times = []
while times.length < TIMES_TO_TRY do
  times << TIME_QUEUE.pop
end

times.sum / times.length

# use the below commented out benchmark to compare parallel with
# sequential publishing
#
# serial_time = Benchmark.realtime do
#   100.times do
#     q.publish({bob: true})
#   end
# end







