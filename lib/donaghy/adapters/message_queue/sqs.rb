require 'aws-sdk'

module Donaghy
  class SQSEvent < Event

    attr_accessor :sqs_message
    def self.from_sqs(sqs_message)
      evt = from_json(sqs_message.body)
      evt.sqs_message = sqs_message
      return evt
    end

    def acknowledge
      sqs_message.delete
    end

  end

  module MessageQueue
    class Sqs
      include Logging

      class SqsQueue

        attr_reader :queue, :queue_name, :opts, :sqs
        def initialize(queue_name, opts = {})
          @opts = opts
          @sqs = opts[:sqs]
          @queue_name = queue_name
          @queue = sqs.queues.create(queue_name)
        end

        def name
          queue_name
        end

        def publish(evt)
          queue.send_message(evt.to_json)
        end

        def receive
          message = queue.receive_message
          return SQSEvent.from_sqs(message) if message
        end

        def destroy
          queue.delete
        end

        def exists?
          queue.exists?
        end

      end

      attr_reader :opts
      def initialize(opts = {})
        @opts = opts
      end

      def find_by_name(queue_name)
        SqsQueue.new(queue_name, sqs: sqs)
      end

    private
      def sqs
        config_hash = opts.dup.delete_if {|k,v| v.nil? }
        @sqs ||= AWS::SQS.new(config_hash)
      end

    end
  end
end
