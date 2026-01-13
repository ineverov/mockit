# frozen_string_literal: true

module Mockit
  # Wrapper for cache store
  class Store
    # Store overrides for a service under the current request's mock id.
    #
    # @param service [String] service identifier
    # @param overrides [Hash] JSON-serializable overrides to store
    # @param ttl [Integer] expiration in seconds (default: 600)
    def self.write(service:, overrides:, ttl: 600)
      key = current_mock_key(service:)
      Mockit.logger.info "Setting key #{key} with value #{overrides.to_json}"
      Mockit.storage.write(key, overrides.to_json, expires_in: ttl)
      # track the service under the current mock id so we can remove all services for a mock
      return unless current_mock_id

      add_service_for_mock(current_mock_id, service)
    end

    # Read stored overrides for a service under the current request's mock id.
    #
    # @param service [String]
    # @return [Hash,nil] parsed overrides or nil when not present
    def self.read(service:)
      key = current_mock_key(service: service)
      json = Mockit.storage.read(key)
      json ? JSON.parse(json) : nil
    end

    # Delete stored overrides for a service under the current request's mock id.
    # Also removes the service from the per-mock registry when present.
    #
    # @param service [String]
    def self.delete(service:)
      key = current_mock_key(service: service)
      Mockit.storage.delete(key)
      # remove service from registry for current mock id
      return unless current_mock_id

      remove_service_for_mock(current_mock_id, service)
    end

    # Mappings are stored under a single key to allow matching by filters.
    # Each mapping is a hash: { id: <mock_id>, match: <match_hash>, created_at: <time>, ttl: <seconds> }
    MAPPINGS_KEY = "mockit:mappings"

    # Write a mapping rule that associates an incoming request (by match criteria)
    # with a `mock_id`.
    #
    # @param match [Hash] matching criteria (e.g. { "path" => "^/x$" })
    # @param mock_id [String] mock id to associate
    # @param ttl [Integer] time-to-live in seconds for this mapping
    def self.write_mapping(match:, mock_id:, ttl: 3600)
      mappings = read_mappings
      mappings.reject! { |m| expired_mapping?(m) }

      mappings << { "id" => mock_id, "match" => match, "created_at" => Time.now.to_i, "ttl" => ttl }

      Mockit.storage.write(MAPPINGS_KEY, mappings.to_json)
    end

    # Read and return all non-expired mappings.
    # Expired mappings are pruned and persisted back to storage.
    #
    # @return [Array<Hash>] list of mapping hashes
    def self.read_mappings
      json = Mockit.storage.read(MAPPINGS_KEY)
      return [] unless json

      parse_and_prune_mappings(json)
    end

    def self.parse_and_prune_mappings(json)
      mappings = JSON.parse(json)

      original_size = mappings.size
      mappings.reject! { |m| expired_mapping?(m) }

      Mockit.storage.write(MAPPINGS_KEY, mappings.to_json) if mappings.size != original_size

      mappings
    rescue JSON::ParserError
      []
    end

    # Remove any mappings that reference the given `mock_id`.
    #
    # @param mock_id [String]
    def self.delete_mapping(mock_id:)
      mappings = read_mappings
      mappings.reject! { |m| m["id"] == mock_id }
      Mockit.storage.write(MAPPINGS_KEY, mappings.to_json)
    end

    # Returns whether a mapping has expired based on its `created_at` and `ttl`.
    #
    # @param mapping [Hash]
    # @return [Boolean]
    def self.expired_mapping?(mapping)
      return false unless mapping["ttl"] && mapping["created_at"]

      mapping["created_at"] + mapping["ttl"] < Time.now.to_i
    end

    SERVICES_KEY_PREFIX = "mockit:services"

    # Build the storage key for the per-mock services registry.
    #
    # @param mock_id [String]
    # @return [String]
    def self.services_key_for(mock_id)
      "#{SERVICES_KEY_PREFIX}:#{mock_id}"
    end

    # Register a service name under a mock id (used to delete all services later).
    #
    # @param mock_id [String]
    # @param service [String]
    def self.add_service_for_mock(mock_id, service)
      key = services_key_for(mock_id)
      services = read_services_for_mock(mock_id)
      services << service unless services.include?(service)
      Mockit.storage.write(key, services.to_json)
    end

    # Remove a service name from a mock's registry.
    #
    # @param mock_id [String]
    # @param service [String]
    def self.remove_service_for_mock(mock_id, service)
      key = services_key_for(mock_id)
      services = read_services_for_mock(mock_id)
      services.reject! { |s| s == service }
      Mockit.storage.write(key, services.to_json)
    end

    # Read the list of services registered for a given mock id.
    #
    # @param mock_id [String]
    # @return [Array<String>]
    def self.read_services_for_mock(mock_id)
      json = Mockit.storage.read(services_key_for(mock_id))
      return [] unless json

      begin
        JSON.parse(json)
      rescue JSON::ParserError
        []
      end
    end

    # Return the current request's mock id from RequestStore.
    #
    # @return [String,nil]
    def self.current_mock_id
      RequestStore.store[:mockit_id]
    end

    # Set the current request's mock id in RequestStore.
    #
    # @param id [String]
    def self.mock_id=(id)
      RequestStore.store[:mockit_id] = id
    end

    # Construct the storage key for a mock/service pair.
    #
    # @param service [String]
    # @return [String]
    def self.current_mock_key(service:)
      "mockit:#{current_mock_id}:#{service}"
    end

    # Delete all stored mocks and mappings for the current request's mock id.
    # If no mock id is present in the request store this method is a no-op to avoid clearing unrelated data.
    def self.delete_all
      mock_id = current_mock_id
      return unless mock_id

      # delete all service keys for the mock
      services = read_services_for_mock(mock_id)
      services.each do |svc|
        key = "mockit:#{mock_id}:#{svc}"
        Mockit.storage.delete(key)
      end

      # delete the services registry for the mock
      Mockit.storage.delete(services_key_for(mock_id))

      # delete mappings that reference this mock id
      delete_mapping(mock_id: mock_id)
    end
  end
end
