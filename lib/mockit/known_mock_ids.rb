# frozen_string_literal: true

module Mockit
  # Tracks which mock ids currently have at least one live override, so the
  # scenario-picker UI can offer them in a picker instead of requiring a mock
  # id to be typed/copy-pasted from wherever it came from. Self-pruning like
  # Store's mappings (same {id, created_at, ttl} shape and expiry check) --
  # an ephemeral mock id used by one CI run ages out on its own rather than
  # accumulating forever.
  module KnownMockIds
    KEY = "mockit:known_mock_ids"
    LOCK_KEY = "mockit:known_mock_ids:lock"

    # @param mock_id [String]
    # @param ttl [Integer] how long this mock id stays listed
    def self.remember(mock_id, ttl:)
      return unless mock_id

      DistributedLock.new(Mockit.storage, LOCK_KEY).synchronize do
        ids = read.reject { |e| e["id"] == mock_id }
        ids << { "id" => mock_id, "created_at" => Time.now.to_i, "ttl" => ttl }
        Mockit.storage.write(KEY, ids.to_json)
      end
    end

    # Stop listing a mock id (used once everything under it has been torn down).
    #
    # @param mock_id [String]
    def self.forget(mock_id)
      DistributedLock.new(Mockit.storage, LOCK_KEY).synchronize do
        ids = read.reject { |e| e["id"] == mock_id }
        Mockit.storage.write(KEY, ids.to_json)
      end
    end

    # Mock ids with at least one live (unexpired) override, most recently
    # touched first. Expired entries are pruned as a side effect of reading.
    # Ordering comes from array position, not `created_at` -- `remember`
    # always re-appends a touched id at the end, and created_at's one-second
    # resolution isn't fine-grained enough to break ties between ids touched
    # in the same second.
    #
    # @return [Array<String>]
    def self.all
      entries = read
      fresh = entries.reject { |e| Store.expired_mapping?(e) }
      Mockit.storage.write(KEY, fresh.to_json) if fresh.size != entries.size

      fresh.reverse.map { |e| e["id"] }
    end

    def self.read
      json = Mockit.storage.read(KEY)
      return [] unless json

      JSON.parse(json)
    rescue JSON::ParserError
      []
    end
  end
end
