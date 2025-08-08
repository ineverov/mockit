# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Store do
  let(:mock_id) { "test-123" }

  before do
    RequestStore.store[:mock_id] = mock_id
  end

  it "writes and reads mocked data from cache" do
    described_class.write(service: "test_service", overrides: { success: true })

    result = described_class.read(service: "test_service")

    expect(result).to eq("success" => true)
  end

  it "deletes mock data from cache" do
    described_class.write(service: "test_service", overrides: { success: true })
    described_class.delete(service: "test_service")
    result = described_class.read(service: "test_service")
    expect(result).to eq(nil)
  end

  it "returns nil if no data is present" do
    result = described_class.read(service: "unknown")
    expect(result).to be_nil
  end

  it "generates the correct cache key" do
    key = described_class.current_mock_key(service: "svc")
    expect(key).to eq("mockit:#{mock_id}:svc")
  end

  it "uses Mockit.default_ttl when ttl is not provided" do
    allow(Mockit).to receive(:default_ttl).and_return(42)
    key = described_class.current_mock_key(service: "svc")
    expect(Mockit.storage).to receive(:write).with(key, { success: true }.to_json, expires_in: 42)
    described_class.write(service: "svc", overrides: { success: true })
  end

  it "memoizes reads within the same request and invalidates on write/delete" do
    key = described_class.current_mock_key(service: "svc")

    # Simulate storage read once and memoize
    allow(Mockit.storage).to receive(:read).with(key).and_return({ a: 1 }.to_json)

    first = described_class.read(service: "svc")
    second = described_class.read(service: "svc")
    expect(first).to eq("a" => 1)
    expect(second).to eq("a" => 1)
    expect(Mockit.storage).to have_received(:read).once

    # Invalidate memo on write
    allow(Mockit.storage).to receive(:write).and_return(true)
    described_class.write(service: "svc", overrides: { a: 2 }, ttl: 1)
    allow(Mockit.storage).to receive(:read).with(key).and_return({ a: 2 }.to_json)
    updated = described_class.read(service: "svc")
    expect(updated).to eq("a" => 2)

    # Invalidate memo on delete
    allow(Mockit.storage).to receive(:delete).with(key).and_return(true)
    described_class.delete(service: "svc")
    allow(Mockit.storage).to receive(:read).with(key).and_return(nil)
    after_delete = described_class.read(service: "svc")
    expect(after_delete).to be_nil
  end
end
