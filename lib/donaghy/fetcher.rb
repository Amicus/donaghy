require "aws-sdk"

module Donaghy
  class Fetcher

    attr_reader :distributor
    def initialize(distributor)
      @distributor = distributor
    end



  #private
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
