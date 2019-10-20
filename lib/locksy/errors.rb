module Locksy
  class LockNotOwnedError < RuntimeError
    attr_reader :lock, :current_owner, :current_expiry

    def initialize(msg = nil, lock:, current_owner: nil, current_expiry: nil)
      @lock = lock
      @current_owner = current_owner
      @current_expiry = current_expiry

      if msg.nil?
        msg = "Unable to manipulate lock #{lock.lock_name} for #{lock.owner}."
        msg += " Lock currently owned by #{current_owner}." if current_owner
        msg += " Lock unnavailable until #{current_expiry}." if current_expiry
      end

      super msg
    end
  end
end
