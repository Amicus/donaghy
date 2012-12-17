module Donaghy

  module Service

    def self.included(klass)
      klass.send(:include, Sidekiq::Worker)
    end

  end

end
