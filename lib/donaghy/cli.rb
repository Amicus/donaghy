require 'pry'

module Donaghy
  class CLI

    attr_reader :argv
    def initialize(argv)
      @argv = argv
    end

    def console
      binding.pry
    end

  end
end
