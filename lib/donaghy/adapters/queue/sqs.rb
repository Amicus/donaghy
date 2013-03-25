module Donaghy
  class SQSEvent < Event

    attr_accessor :sqs_message
    def self.from_sqs(sqs_message)
      evt = from_json(sqs_message.body)
      evt.sqs_message = sqs_message
    end

  end

  module Queue
    class SQS

      def self.find_by_name(queue_name)
        new(queue_name)
      end

      attr_reader :queue, :queue_name
      def initialize(queue_name, opts = {})
        @queue_name = queue_name
        @queue = sqs.queues.create(queue_name)
      end

      def publish(hash)
        queue.send_message(Event.from_hash(hash).to_json)
      end

      def receive
        SQSEvent.new(queue.receive_message)
      end

    private
      def sqs
        @sqs ||= AWS::SQS.new({
          access_key_id: 'YOUR_ACCESS_KEY_ID',
          secret_access_key: 'YOUR_SECRET_ACCESS_KEY',
          sqs_endpoint: "localhost",
          sqs_port: '9324',
          use_ssl: false,
        })
      end

    end
  end
end
