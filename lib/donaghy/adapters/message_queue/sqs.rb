require 'aws-sdk'

module Donaghy
  class SQSEvent < Event
    include Logging

    class EventRequeuedButTryingToHeartbeat < StandardError; end

    attr_accessor :sqs_message
    def self.from_sqs(sqs_message)
      evt = from_json(sqs_message.body)
      evt.sqs_message = sqs_message
      @requeued = false
      return evt
    end

    def acknowledge
      sqs_message.delete
    end

    def heartbeat(timeout=15)
      raise EventRequeuedButTryingToHeartbeat if @requeued
      sqs_message.visibility_timeout = timeout
    rescue AWS::SQS::Errors::InvalidParameterValue => e
      logger.warn("could not heartbeat #{id} #{path} due to #{e.inspect}")
    end

    def requeue(opts = {})
      @requeued = true
      logger.info("resetting visibility timeout to #{opts[:delay] || 1} for #{path}")
      sqs_message.visibility_timeout = (opts[:delay] || 1).to_i
    rescue AWS::SQS::Errors::InvalidParameterValue => e
      logger.warn("could not requeue #{id} #{path} due to #{e.inspect}")
    end

  end

  module MessageQueue
    class Sqs

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

        def publish(evt, opts={})
          opts[:delay_seconds] = opts.delete(:delay) if opts[:delay]
          queue.send_message(evt.to_json, opts)
        end

        def receive
          message = queue.receive_message(wait_time_seconds: (opts[:wait_time_seconds] || 5))
          return SQSEvent.from_sqs(message) if message
        end

        def destroy
          queue.delete
        end

        def exists?
          queue.exists?
        end

        def length
          queue.approximate_number_of_messages
        end

        def length_of_delayed
          queue.approximate_number_of_messages_delayed
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
