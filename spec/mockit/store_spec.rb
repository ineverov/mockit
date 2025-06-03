# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Store do
  let(:mock_id) { "test-123" }

  before do
    RequestStore.store[:mock_id] = mock_id
  end

  it "writes and reads mocked data from Redis" do
    described_class.write(service: "test_service", overrides: { success: true })

    result = described_class.read(service: "test_service")

    expect(result).to eq("success" => true)
  end

  it "returns nil if no data is present" do
    result = described_class.read(service: "unknown")
    expect(result).to be_nil
  end

  it "generates the correct Redis key" do
    key = described_class.current_mock_key(service: "svc")
    expect(key).to eq("mockit:#{mock_id}:svc")
  end
end
