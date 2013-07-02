# Donaghy

Donaghy is basically a pub-sub system that can also handle doing background jobs in a sidekiq-like manner. It supports adapters for storage and message queue with a generic interface. It comes with production-ready adapters for torquebox infinispan cache (for storage) and sqs (for the queues). It also has in-memory stores and queues for testing and a redis-based store and queue for development (not recommended for production).

It's multi-threaded (heads up) and will make sure a message gets run *at least once.* It relies on shared storage and a queueing implementation that supports FIFO.

## Installation

Add this line to your application's Gemfile:

    gem 'donaghy'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install donaghy

## Configuration

You basically pass in your configuration information to the Donaghy.configuration= method.  A full donaghy config might look like:

```yaml
message_queue:
  - :sqs
  - access_key: 'abc'
    secret_access_key: 'abc'
storage: :torquebox_storage
name: donaghy-web
concurrency: 10
cluster_concurrency: 4
services:
  - donaghy_web_pusher
```

Specifying the storage and message queue will attempt to load the class Donaghy::Adapters::Storage::YourCamelizedString

For example, the above config will use Donaghy::Adapters::MessageQueue::Sqs and Donaghy::Adapters::Storage::TorqueboxStorage and will pass in the options hash {access_key: 'abc', secret_access_key: 'abc'} to the sqs class when creating a new instance for use.

You should name your "set of services" (basically a named group of similar classes) something. In the config above, we are setting it to "donaghy-web"
You set the concurrency you want (number of simulatenous workers in this group), the cluster concurrency (the number of workers handling donaghy internals).

You then list out the services - these are the classes handling pub-sub style. You do not need to list out the sidekiq-style classes.


## Usage

There are two ways to define donaghy workers.  The first will be familiar to sidekiq and resque users:

```ruby
class MyBackgroundWorker
  include Donaghy::Service

  def perform(*args)
    # do work. Args are passed through json, so only json-serialzable args should be passed (like sidekiq)
  end
end
```
Like sidekiq, you can have this job run in the background by calling

```ruby
MyBackgroundWorker.perform_async(*args)
```

The other way is more pub-sub style receives. Event paths are passed through File.fnmatch so you can use any wildcard characters available to that method.

```ruby
class MyBackgroundListener
  include Donaghy::Service

  receives "/path/to/my/event*", :my_handler

  def my_handler(evt)
    # this method will get passed the actual event. See event.rb for methods on that event
  end
end
```

You can trigger an event from any donaghy service:

```ruby
MyBackgroundListener.new.root_trigger("path/to/my/event/abc", payload: {my_arg1: 'coolest'})
```

or from the Donaghy global event publisher

```ruby
Donaghy.event_publisher.root_trigger("/path/to/my/event/def", payload: {anything_i_want: true} )
```

### Middleware

Like sidekiq, you can add your own custom middleware to message processing.  We have one that sends our errors to errplane. A minimal implementation might be:

```ruby
module Donaghy
  class ErrplaneMiddleware
    def call(event, handler_info)
      yield
    rescue Exception => e
      Errplane.transmit_unless_ignorable(e, :custom_data => {:event => event.to_hash(without: :received_on)})
      raise e
    end
  end
end

::Donaghy.middleware do |m|
  m.add ::Amicus::Donaghy::ErrplaneMiddleware
end
```

Currently Donaghy only support server-side middleware, not client-side.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
