module Locksy
  # AbstractLock allows us to declare the interface for locks.
  # Any locks created should follow this interface
  #
  # disabling this cop because we are declaring this as an interface and deliberately not using here
  # rubocop:disable Lint/UnusedMethodArgument
  class LockInterface
    attr_reader :owner, :default_expiry, :default_extension, :lock_name
    attr_writer :logger

    def initialize(lock_name: generate_default_lock_name, owner: generate_default_owner,
      default_expiry: nil, default_extension: nil, logger: nil, **_args)
      raise NotImplementedError.new 'This is an abstract class - instantiation is not supported'
    end

    # should return a boolean denoting lock obtained (true) or not (false)
    def obtain_lock(expire_after: default_expiry, **_args)
      raise NotImplementedError.new 'Obtaining a lock is not supported'
    end

    # should raise a LockNotOwnedError if the lock is not owned by the requested owner
    def refresh_lock(expire_after: default_extension, **_args)
      raise NotImplementedError.new 'Refreshing a lock is not supported'
    end

    # should raise a LockNotOwnedError if the lock is not owned by the requested owner
    def release_lock(**_args)
      raise NotImplementedError.new 'Releasing a lock is not supported'
    end

    # should raise a LockNotOwnedError if the lock is not owned by the requested owner
    def with_lock(expire_after: default_expiry, **_args)
      raise NotImplementedError.new 'Working with a lock is not supported'
    end

    protected

    attr_reader :logger, :generate_default_owner, :generate_default_lock_name
  end
  # rubocop:enable Lint/UnusedMethodArgument
end
