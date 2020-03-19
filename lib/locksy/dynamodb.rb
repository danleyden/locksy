require_relative './base_lock'
require 'forwardable'

module Locksy
  class DynamoDB < BaseLock
    extend Forwardable

    attr_reader :dynamo_client, :table_name

    def_delegators 'self.class'.to_sym, :default_table, :default_client

    def initialize(dynamo_client: default_client, table_name: default_table, **_args)
      # lazy-load the gem to avoid forcing a dependency on the implementation
      require 'aws-sdk-dynamodb'
      @dynamo_client = dynamo_client
      @table_name = table_name
      @_timeout_stopper = ConditionVariable.new
      @_timeout_mutex = Mutex.new
      super
    end

    def obtain_lock(expire_after: default_expiry, wait_for: nil, **_args)
      stop_waiting_at = wait_for ? now + wait_for : nil
      begin
        expire_at = expiry(expire_after)
        logger.debug "trying to obtain lock #{lock_name} for #{owner} to be held until #{expire_at}"
        dynamo_client.put_item \
          ({ table_name: table_name,
             item: { id: lock_name, expires: expire_at, lock_owner: owner },
             condition_expression: '(attribute_not_exists(expires) OR expires < :now) ' \
                                   'OR (attribute_not_exists(lock_owner) OR lock_owner = :owner)',
             expression_attribute_values: { ':now' => now, ':owner' => owner } })
        logger.debug "acquired lock #{lock_name} for #{owner} to be held until #{expire_at}"
        expire_at
      rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
        if stop_waiting_at && stop_waiting_at > now
          # Retry at a maximum of 1/2 of the remaining time until the
          # current lock expires or the remaining time from the what the
          # caller was willing to wait, subject to a minimum of 0.1s to
          # prevent busy looping.
          if (current = retrieve_current_lock).nil?
            retry_wait = 0.1
          else
            retry_wait = [stop_waiting_at - now, [(current[:expires] - now) / 2, 0.1].max].min
          end
          logger.debug "Attempt to acquire lock #{lock_name} for #{owner} failed - "\
            "lock owned by #{current[:owner]} until #{format('%0.02f', current[:expires])}. " \
            "Will retry in #{format('%0.02f', retry_wait)}s"
          _wait_for_timeout retry_wait
          retry unless self.class.shutting_down?
        end
        logger.debug "Attempt to acquire lock #{lock_name} for #{owner} failed. Giving up"
        raise build_not_owned_error_from_remote
      end
    end

    def release_lock
      dynamo_client.delete_item \
        ({ table_name: table_name,
           key: { id: lock_name },
           condition_expression: '(attribute_not_exists(lock_owner) OR lock_owner = :owner) ' \
                                 'OR (attribute_not_exists(expires) OR expires < :expires)',
           expression_attribute_values: { ':owner' => owner, ':expires' => now } })
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      raise build_not_owned_error_from_remote
    end

    def refresh_lock(expire_after: default_extension, **_args)
      expire_at = expiry(expire_after)
      dynamo_client.update_item \
        ({ table_name: table_name,
           key: { id: lock_name },
           update_expression: 'SET expires = :expires',
           condition_expression: 'attribute_exists(expires) AND expires > :now ' \
                                 'AND lock_owner = :owner',
           expression_attribute_values: { ':expires' => expire_at,
                                          ':owner' => owner,
                                          ':now' => now } })
      expire_at
    rescue Aws::DynamoDB::Errors::ConditionalCheckFailedException
      obtain_lock expire_after: expire_after
    end

    def create_table
      dynamo_client.create_table(table_name: table_name,
                                 key_schema: [{ attribute_name: 'id', key_type: 'HASH' }],
                                 attribute_definitions: [{ attribute_name: 'id',
                                                           attribute_type: 'S' }],
                                 provisioned_throughput: { read_capacity_units: 10,
                                                           write_capacity_units: 10 })
    rescue Aws::DynamoDB::Errors::ResourceInUseException => ex
      unless ex.message == 'Cannot create preexisting table' ||
          ex.message.start_with?('Table already exists')
        raise ex
      end
    end

    def force_unlock!
      dynamo_client.delete_item(table_name: table_name, key: { id: lock_name })
    end

    class << self
      attr_writer :default_client, :default_table

      def default_table
        @default_table ||= 'default_locks'
      end

      def default_client
        @default_client ||= create_client
      end

      def create_client(**args)
        # require at runtime to avoid a gem dependency
        require 'aws-sdk-dynamodb'
        Aws::DynamoDB::Client.new(**args)
      end
    end

    def _wait_for_timeout(timeout)
      @_timeout_mutex.synchronize { @_timeout_stopper.wait(@_timeout_mutex, timeout) }
    end

    def _interrupt_waiting
      @_timeout_mutex.synchronize { @_timeout_stopper.broadcast }
    end

    private

    def retrieve_current_lock
      item = dynamo_client.get_item(table_name: table_name, key: { id: lock_name }).item
      return nil if item.nil?
      { lock_name: item['id'], owner: item['lock_owner'], expires: item['expires'] }
    end

    def build_not_owned_error_from_remote
      current = retrieve_current_lock || {}
      LockNotOwnedError.new(lock: self, current_owner: current['owner'],
                            current_expiry: current['expires'])
    rescue RuntimeError # in the case that there is a different error raised, ignore it
      LockNotOwnedError.new(lock: self)
    end
  end
end
