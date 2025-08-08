# frozen_string_literal: true

module Mockit
  # Wrapper for cache store
  class Store
    require "json"

    # Small per-request memoization to avoid repeated cache lookups
    def self._memo
      ::RequestStore.store[:mockit_store_memo] ||= {}
    end

    def self.write(service:, overrides:, ttl: Mockit.default_ttl)
      key = current_mock_key(service:)
      Mockit.logger.info "Setting key #{key} with value #{overrides.to_json}"
      _memo.delete(key)
      Mockit.storage.write(key, overrides.to_json, expires_in: ttl)
    end

    def self.read(service:)
      key = current_mock_key(service: service)
      return _memo[key] if _memo.key?(key)

      json = Mockit.storage.read(key)
      _memo[key] = json ? JSON.parse(json) : nil
    end

    def self.delete(service:)
      key = current_mock_key(service: service)
      _memo.delete(key)
      Mockit.storage.delete(key)
    end

    def self.current_mock_id
      RequestStore.store[:mock_id]
    end

    def self.mock_id=(id)
      RequestStore.store[:mock_id] = id
    end

    def self.current_mock_key(service:)
      "mockit:#{current_mock_id}:#{service}"
    end
  end
end
