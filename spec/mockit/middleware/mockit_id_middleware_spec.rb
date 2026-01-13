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
end
