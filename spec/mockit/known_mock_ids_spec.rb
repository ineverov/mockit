# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::KnownMockIds do
  # Other spec files (e.g. mocks_controller_spec.rb) write overrides under
  # their own mock ids and deliberately don't always tear them down, which
  # now also leaves them in this shared registry. Reset before each test too,
  # not just after, so this file's exact-list assertions aren't at the mercy
  # of what ran before it in the same process.
  before { Mockit.storage.delete(described_class::KEY) }
  after { Mockit.storage.delete(described_class::KEY) }

  describe ".remember and .all" do
    it "lists a remembered mock id" do
      described_class.remember("mock-a", ttl: 600)

      expect(described_class.all).to eq(["mock-a"])
    end

    it "is a no-op for a nil mock id" do
      expect { described_class.remember(nil, ttl: 600) }.not_to raise_error
      expect(described_class.all).to eq([])
    end

    it "does not duplicate an already-known mock id, and re-freshens its position" do
      described_class.remember("mock-a", ttl: 600)
      described_class.remember("mock-b", ttl: 600)
      described_class.remember("mock-a", ttl: 600)

      expect(described_class.all).to eq(%w[mock-a mock-b])
    end

    it "orders by most-recently-touched, not by service count" do
      described_class.remember("mock-a", ttl: 600)
      described_class.remember("mock-b", ttl: 600)

      expect(described_class.all).to eq(%w[mock-b mock-a])
    end

    it "drops an entry once it expires" do
      described_class.remember("expiring", ttl: -1)

      expect(described_class.all).not_to include("expiring")
    end

    it "returns an empty list when storage holds invalid JSON" do
      Mockit.storage.write(described_class::KEY, "not-json")

      expect(described_class.all).to eq([])
    end
  end

  describe ".forget" do
    it "removes a mock id from the known list" do
      described_class.remember("mock-a", ttl: 600)

      described_class.forget("mock-a")

      expect(described_class.all).not_to include("mock-a")
    end

    it "leaves other mock ids untouched" do
      described_class.remember("mock-a", ttl: 600)
      described_class.remember("mock-b", ttl: 600)

      described_class.forget("mock-a")

      expect(described_class.all).to eq(["mock-b"])
    end
  end
end
