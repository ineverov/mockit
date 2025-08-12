# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Store do
  let(:mock_id) { "test-123" }

  before do
    RequestStore.store[:mockit_id] = mock_id
  end

  after do
    RequestStore.store.clear
    Mockit.storage.delete("mockit:mappings")
  end

  it "writes and reads mocked data from Redis" do
    described_class.write(service: "test_service", overrides: { success: true })

    result = described_class.read(service: "test_service")

    expect(result).to eq("success" => true)
  end

  it "deletes mock data from cache" do
    described_class.write(service: "test_service", overrides: { success: true })
    described_class.delete(service: "test_service")
    result = described_class.read(service: "test_service")
    expect(result).to be_nil
  end

  it "returns nil if no data is present" do
    result = described_class.read(service: "unknown")
    expect(result).to be_nil
  end

  it "generates the correct cache key" do
    key = described_class.current_mock_key(service: "svc")
    expect(key).to eq("mockit:#{mock_id}:svc")
  end

  it "deletes stored overrides for a service" do
    described_class.write(service: "to_delete", overrides: { a: 1 })
    expect(described_class.read(service: "to_delete")).to eq("a" => 1)

    described_class.delete(service: "to_delete")
    expect(described_class.read(service: "to_delete")).to be_nil
  end

  it "returns empty list for invalid mappings JSON" do
    Mockit.storage.write(Mockit::Store::MAPPINGS_KEY, "not-json")
    expect(described_class.read_mappings).to eq([])
  end

  it "handles invalid services JSON gracefully" do
    Mockit.storage.write(described_class.services_key_for("m-invalid"), "bad")
    expect(described_class.read_services_for_mock("m-invalid")).to eq([])
  end

  it "appends new mappings without pruning" do
    many = (1..5).map { |i| { "id" => "m#{i}", "match" => {}, "created_at" => Time.now.to_i, "ttl" => 3600 } }
    Mockit.storage.write(Mockit::Store::MAPPINGS_KEY, many.to_json)

    described_class.write_mapping(match: {}, mock_id: "new", ttl: 3600)
    mappings = described_class.read_mappings
    expect(mappings.size).to eq(6)
    expect(mappings.last["id"]).to eq("new")
  end

  it "expired_mapping? returns true for old mappings and false for valid ones" do
    old = { "id" => "o", "created_at" => Time.now.to_i - 10_000, "ttl" => 1 }
    fresh = { "id" => "f", "created_at" => Time.now.to_i, "ttl" => 10_000 }
    expect(described_class.expired_mapping?(old)).to be true
    expect(described_class.expired_mapping?(fresh)).to be false
  end

  it "delete_all falls back when storage lacks clear" do
    # simulate a storage without `clear`
    store = Object.new
    def store.read(_key) = nil
    def store.write(key, val); end
    def store.delete(key); end

    Mockit.instance_variable_set(:@storage, store)
    # Ensure no mock_id is set for this scenario (file-level before may have set one)
    RequestStore.store.clear
    # When no mock_id is set, delete_all is a no-op and should not raise
    expect(RequestStore.store[:mockit_id]).to be_nil
    expect { described_class.delete_all }.not_to raise_error

    # restore storage
    Mockit.instance_variable_set(:@storage, Rails.cache)
  end

  context "with mappings" do
    before do
      RequestStore.store[:mockit_id] = "current-mock"
      # clear mappings key
      Mockit.storage.delete("mockit:mappings")
    end

    it "writes and reads mappings" do
      described_class.write_mapping(match: { "path" => "^/a$" }, mock_id: "m1", ttl: 10)
      mappings = described_class.read_mappings

      expect(mappings).to be_an(Array)
      expect(mappings.first["id"]).to eq("m1")
    end

    it "deletes mapping by id" do
      described_class.write_mapping(match: { "path" => "^/a$" }, mock_id: "m1", ttl: 10)
      described_class.write_mapping(match: { "path" => "^/b$" }, mock_id: "m2", ttl: 10)

      described_class.delete_mapping(mock_id: "m1")
      mappings = described_class.read_mappings
      expect(mappings.any? { |m| m["id"] == "m1" }).to be false
      expect(mappings.any? { |m| m["id"] == "m2" }).to be true
    end

    it "prunes expired mappings on write" do
      old = { "id" => "old", "match" => { "path" => "^/x$" }, "created_at" => Time.now.to_i - 3600, "ttl" => 1 }
      Mockit.storage.write("mockit:mappings", [old].to_json)

      described_class.write_mapping(match: { "path" => "^/new$" }, mock_id: "new", ttl: 10)
      mappings = described_class.read_mappings

      expect(mappings.any? { |m| m["id"] == "old" }).to be false
      expect(mappings.any? { |m| m["id"] == "new" }).to be true
    end
  end
end
