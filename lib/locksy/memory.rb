require_relative './base_lock'

module Locksy
  class Memory < BaseLock
    @_singleton_mutex = Mutex.new
    @_datastore = {}
    @_data_change = ConditionVariable.new

    def obtain_lock(expire_after: default_expiry, wait_for: nil, **_args)
      stop_waiting_at = wait_for ? now + wait_for : nil
      begin
        current = nil
        self.class._synchronize do
          current = _in_mutex_retrieve_lock
          self.class._datastore[lock_name] = [owner, expiry(expire_after)]
          self.class._notify_data_change
        end
      rescue LockNotOwnedError => ex
        if stop_waiting_at && stop_waiting_at > now
          # Maximum wait time for the condition variable before retrying
          # Because it is possible that a condition variable will not be
          # triggered, or may be triggered by something that is not what
          # was expected.
          # Retry at a maximum of 1/2 of the remaining time until the
          # current lock expires or the remaining time from the what the
          # caller was willing to wait, subject to a minimum of 0.1s to
          # prevent busy looping.
          cv_timeout = [stop_waiting_at - now, [(ex.current_expiry - now) / 2, 0.1].max].min
          self.class._synchronize { self.class._wait_for_data_change(cv_timeout) }
          retry unless self.class.shutting_down?
        end
        raise ex
      end
    end

    def release_lock
      self.class._synchronize do
        _in_mutex_retrieve_lock
        self.class._datastore.delete lock_name
        self.class._notify_data_change
      end
    end

    def refresh_lock(expire_after: default_extension, **_args)
      obtain_lock expire_after: expire_after
    end

    class << self
      attr_reader :_datastore

      # This is needed to allow tests to inject and control the condition variable
      attr_writer :_data_change

      def release_all!
        _synchronize { @_datastore = {} }
      end

      def _synchronize(&blk)
        @_singleton_mutex.synchronize(&blk)
      end

      # THIS IS DANGEROUS... CALL ONLY WHEN SYNCHRONIZED IN THE MUTEX
      def _wait_for_data_change(timeout = nil)
        @_data_change.wait(@_singleton_mutex, timeout)
      end

      # THIS IS DANGEROUS... CALL ONLY WHEN SYNCHRONIZED IN THE MUTEX
      def _notify_data_change
        @_data_change.broadcast
      end
    end

    at_exit do
      _synchronize { _notify_data_change }
    end

    private

    def _in_mutex_retrieve_lock
      current = self.class._datastore[lock_name]
      if current && current[0] != owner && current[1] > now
        raise LockNotOwnedError.new(lock: self, current_owner: current[0],
                                    current_expiry: current[1])
      end
      current
    end
  end
end
