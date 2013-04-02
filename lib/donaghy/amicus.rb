require 'donaghy'
require 'cluster-fuck'

module Donaghy
  module Amicus
    def self.configure(config_file = nil)
      reader = ClusterFuck::Reader.new("donaghy")
      config = reader.read
      Donaghy.configuration = config.merge(config_file: config_file)
    end
  end
end
