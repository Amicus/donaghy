require 'hashie/mash'
require 'json'

module Donaghy

  class Event
    include Logging

    def self.from_json(json)
      from_hash(JSON.load(json))
    end

    def self.from_hash(hsh)
      new(hsh.merge(without_append: true))
    end

    # (topper) we use value and timer for sending to errplane (at least)
    ATTRIBUTE_METHODS = [
        :id,
        :version,
        :payload,
        :generated_at,
        :generated_by,
        :path,
        :value,
        :timer,
        :received_on,
        :retry_count,
    ]

    attr_accessor *ATTRIBUTE_METHODS
    def initialize(opts)
      without_append = opts.delete(:without_append)

      @generated_at = Time.now.utc
      opts.each_pair do |key, value|
        self.send("#{key}=", value)
      end
      @id ||= Celluloid::UUID.generate
      @retry_count ||= 0
      @generated_by ||= []
      @generated_by << path unless without_append
      self
    end

    def payload=(val)
      @payload = if val.kind_of?(Hash)
                   Hashie::Mash.new(val)
                 else
                   val
                 end
    end

    def generated_at
      if @generated_at.is_a?(String)
        @generated_at = Time.parse(@generated_at)
      else
        @generated_at
      end
    end

    # target isn't serializable - so we don't put it in here,
    # but it can be useful internally
    def to_hash(options = {})
      (ATTRIBUTE_METHODS - Array(options[:without])).inject({}) do |hsh, meth|
        hsh[meth] = send(meth)
        hsh
      end
    end

    def to_json(options = {})
      JSON.dump(to_hash(options.merge(without: [:received_on])))
    rescue StandardError => e
      logger.error("could not to json: #{self.inspect}, had error: #{e.inspect} with backtrace: #{e.backtrace.join("\n")}")
      raise e
    end

    def ==(other)
      !((ATTRIBUTE_METHODS - [:id, :generated_at, :retry_count, :received_on, :timer, :value]).detect {|method| self.send(method) != other.send(method) })
    end

    def acknowledge
      #to be implemented by the MessageQueue adapter
    end

    def heartbeat(timeout=nil)
      # to be implemented by the MessageQueue adapter
    end

    def requeue(opts={})
      (self.received_on || Donaghy.root_queue).publish(self, opts)
      acknowledge
    end

    def inspect
      to_hash.inspect
    end

  end

end
