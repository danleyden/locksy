Locksy
======

Locksy provides support for creating and managing time-limited distributed locks.

Currently there is a local in-memory implementation for single-process testing
and an AWS dynamodb-backed implementation.


Dynamo DB locks
===============

For local development when working with Dynamo DB, it is most useful to work with
the AWS-provided dynamodb docker container and to configure the endpoint to point
to that instance instead of the "real" AWS instance.

To get set up, install docker then:
# docker pull amazon/dynamodb-local
# docker run -p 8000:8000 amazon/dynamodb-local
