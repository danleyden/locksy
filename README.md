Locksy
======

Locksy provides support for creating and managing time-limited distributed locks.

Currently there is a local in-memory implementation for single-process testing
and an AWS dynamodb-backed implementation.

Usage
=====

To create and use a lock:
```ruby
lock = lock_class.new(lock_name: 'my_lock')

begin
  lock.with_lock do
    # safe code
  end
rescue Locksy::LockNotOwnedError => ex
  # handle the case where the lock cannot be obtained
end
```

Because the implementations all follow the same interface, it is generally expected
that you would separate out the choice of which implementation to use from the code
that uses the lock. In the above example, `lock_class` provides the class name of
the implementation to use. The benefit of this is that it allows you to do local
testing with, for example, `Locksy::Memory` implementation which is fast and hreadsafe
but does not provide protection when multiple processes are involved and use the
`Locksy::DynamoDB` implementation in production.

To avoid loading many unnecessary dependencies for all implementaitons, it is necessary
to `require` the lock implementation that you actually need from within your code.

Logging
=======

Locksy does some logging, which by default, will push to STDOUT. If you want to control
the logging, you can either provide an instance of a logger object that meets the ruby
logger interface in to the lock instance (`lock.logger = logger`) or you can control it
for all lock instances by passing in a logger object by calling `Locksy.logger = logger`.

To make locksy less chatty, things like `Locksy.logger = ::Logger.WARN` also work.


Dynamo DB locks
===============

For local development when working with Dynamo DB, it is most useful to work with
the AWS-provided dynamodb docker container and to configure the endpoint to point
to that instance instead of the "real" AWS instance.

To get set up, install docker then:
```shell
docker pull amazon/dynamodb-local
docker run -p 8000:8000 amazon/dynamodb-local
```
