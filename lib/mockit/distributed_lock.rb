# frozen_string_literal: true

module Mockit
  # Distributed lock implementation using cache store
  class DistributedLock
    TIMEOUT = 10 # seconds

    def initialize(storage, lock_key, timeout: TIMEOUT)
      @storage = storage
      @lock_key = lock_key
      @timeout = timeout
      @acquired = false
    end

    # Acquire the lock and execute the block
    def synchronize
      acquire_lock
      yield
    ensure
      release_lock
    end

    private

    attr_reader :storage, :lock_key, :timeout, :acquired

    def acquire_lock
      @lock_token = SecureRandom.uuid
      deadline = Time.now + timeout

      loop do
        break if try_acquire_lock

        raise_timeout_error if Time.now >= deadline

        sleep(0.01 + (rand * 0.02))
      end

      @acquired = true
    end

    def try_acquire_lock
      storage.write(lock_key, @lock_token, expires_in: timeout, unless_exist: true)
    end

    def raise_timeout_error
      raise Mockit::Error, "Mockit: Failed to acquire lock on #{lock_key} within #{timeout} seconds"
    end

    def release_lock
      return unless @acquired
      return unless storage.read(lock_key) == @lock_token

      storage.delete(lock_key)
    end
  end
end
