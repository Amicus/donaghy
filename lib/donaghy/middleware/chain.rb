module Donaghy

  module Middleware

    class Chain
      attr_reader :links

      def initialize
        @links = []
        yield(self) if block_given?
      end

      def add(klass, *args)
        links << Link.new(klass, *args) unless exists?(klass)
      end

      def remove(klass)
        links.delete_if {|link| link.klass == klass }
      end

      def exists?(klass)
        links.any? {|link| link.klass == klass }
      end

      def processors
        links.map(&:processor)
      end

      def execute(*args, &finally)
        links = processors
        executor = ->() do
          if links.empty?
            finally.call
          else
            links.shift.call(*args, &executor)
          end
        end
        executor.call
      end

      class Link
        attr_reader :klass, :args

        def initialize(klass, *args)
          @klass = klass
          @args = args
        end

        def processor
          @klass.new(*args)
        end
      end

    end

  end

end
