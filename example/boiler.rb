require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('./Gemfile', __FILE__)

require 'bundler/setup' if File.exists?(ENV['BUNDLE_GEMFILE'])

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(:default)
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

require 'donaghy/cluster_node'

class Boiler

  attr_reader :server
  def initialize(opts={})
    Donaghy.configuration = opts
    @cluster_node = Donaghy.cluster_node
  end

  def start
    cluster_node.start
  end

  def stop
    cluster_node.stop
  end


end
