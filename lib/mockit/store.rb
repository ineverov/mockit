# frozen_string_literal: true

module Mockit
  # Wrapper for cache store
  class Store
    def self.write(service:, overrides:, ttl: 600)
      key = current_mock_key(service:)
      Rails.logger.info "Setting key #{key} with value #{overrides.to_json}"
      Rails.cache.write(key, overrides.to_json, expires_in: ttl)
    end

    def self.read(service:)
      key = current_mock_key(service: service)
      json = Rails.cache.read(key)
      json ? JSON.parse(json) : nil
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
