module Donaghy

  class Event

    def self.from_json(json)
      from_hash(JSON.load(json))
    end

    def self.from_hash(hsh)
      new(hsh.merge(without_append: true))
    end

    # (topper) we use value and timer for sending to errplane (at least)
    ATTRIBUTE_METHODS = [:version, :payload, :generated_at, :generated_by, :path, :target, :value, :timer]

    attr_accessor *ATTRIBUTE_METHODS
    def initialize(opts)
      without_append = opts.delete(:without_append)

      @generated_at = Time.now.utc
      opts.each_pair do |key, value|
        self.send("#{key}=", value)
      end
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

    # target isn't serializable - so we don't put it in here,
    # but it can be useful internally
    def to_hash(options = {})
      {
          version: version,
          payload: payload,
          generated_at: generated_at,
          generated_by: generated_by,
          path: path,
          value: value,
          timer: timer
      }
    end

    def to_json(options = {})
      JSON.dump(to_hash(options))
    end

    def ==(other)
      (ATTRIBUTE_METHODS - [:generated_at, :target]).inject(true) {|accum, method| accum && self.send(method) == other.send(method) }
    end

  end

end
