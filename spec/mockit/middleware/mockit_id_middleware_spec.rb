# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware::MockitIdMiddleware do
  let(:app) { ->(env) { [200, env, "app"] } }
  let(:middleware) { described_class.new(app) }

  it "stores mock_id from header in RequestStore" do
    allow(Mockit::Store).to receive(:mock_id=).and_call_original
    allow(Mockit::Store).to receive(:write).and_call_original
    expect(Mockit::Store).to receive(:mock_id=).with("mock-header-id")

    env = { "HTTP_X_MOCKIT_ID" => "mock-header-id" }
    status, _headers, _body = middleware.call(env)
    expect(status).to eq(200)
  end

  it "stores mock_id from legacy header in RequestStore" do
    allow(Mockit::Store).to receive(:mock_id=).and_call_original
    allow(Mockit::Store).to receive(:write).and_call_original
    expect(Mockit::Store).to receive(:mock_id=).with("mock-header-id")

    env = { "HTTP_X_MOCK_ID" => "mock-header-id" }
    status, _headers, _body = middleware.call(env)
    expect(status).to eq(200)
  end

  context "with Mockit.default_mock_id set" do
    after { Mockit.default_mock_id = nil }

    it "falls back to the default when no header is present" do
      Mockit.default_mock_id = "dev-default"
      expect(Mockit::Store).to receive(:mock_id=).with("dev-default")

      status, _headers, _body = middleware.call({})
      expect(status).to eq(200)
    end

    it "still prefers an explicit header over the default" do
      Mockit.default_mock_id = "dev-default"
      expect(Mockit::Store).to receive(:mock_id=).with("mock-header-id")

      status, _headers, _body = middleware.call({ "HTTP_X_MOCKIT_ID" => "mock-header-id" })
      expect(status).to eq(200)
    end
  end

  it "sets no mock_id when neither a header nor a default is present" do
    expect(Mockit::Store).not_to receive(:mock_id=)

    status, _headers, _body = middleware.call({})
    expect(status).to eq(200)
  end
end
