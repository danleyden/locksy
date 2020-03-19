require_relative './lock_interface'
require_relative './errors'

require 'securerandom'
require 'socket'

module Locksy
  class BaseLock < LockInterface
    attr_reader :owner, :default_expiry, :default_extension, :lock_name
    attr_writer :logger

    # allow injection of a clock to assist testing
    # do not call or set this outside of tests
    attr_writer :_clock

    # add a class-level flag to allow children to know to stop loops etc.
    @_shutting_down = false

    def initialize(lock_name: generate_default_lock_name, owner: generate_default_owner,
      default_expiry: 10, default_extension: 10, logger: nil, **_args)
      @owner = owner
      @default_expiry = default_expiry
      @default_extension = default_extension
      @lock_name = lock_name
      @logger = logger
    end

    # disabling here because we have a no-op implementation... we're expecting this
    # class to be extended
    # rubocop:disable Style/EmptyMethod
    def obtain_lock(expire_after: default_expiry, **_args); end

    def refresh_lock(expire_after: default_extension, **_args); end

    def release_lock(**_args); end
    # rubocop:enable Style/EmptyMethod

    def with_lock(expire_after: default_expiry, **args)
      if (lock_obtained = obtain_lock(expire_after: expire_after, **args))
        yield
      end
    ensure
      release_lock if lock_obtained
    end

    def self.shutting_down?
      @_shutting_down
    end

    at_exit do
      @_shutting_down = true
    end

    protected

    def now
      (@_clock ||= Time).now.to_f
    end

    def logger
      @logger || Locksy.logger
    end

    def expiry(after)
      now + after
    end

    def generate_default_owner
      "#{Thread.current.object_id}-#{Process.pid}@#{Socket.gethostname}"
    end

    def generate_default_lock_name
      "#{SecureRandom.base64(12)}.#{generate_default_owner}"
    end
  end
end
