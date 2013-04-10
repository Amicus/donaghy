## 0.1.0
* no more sidekiq
* adapters for storage and message queues
* default production to torquebox store and sqs while using redis locally

## 0.0.9
* since nodes are ephemeral, when a client disconnects and reconnects, we need to recreate the nodes

## 0.0.8
* bump sidekiq version required

## 0.0.2

* better thread safety when setting config
* register donaghy configuration in an ephemeral node based on hostname
