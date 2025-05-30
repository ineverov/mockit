require "spec_helper"

RSpec.describe Mockit::Middleware::RequestStore do
  let(:app) { ->(env) { [200, env, "app"] } }
  let(:middleware) { described_class.new(app) }

  it "stores mock_id from header in RequestStore" do
    allow(Mockit::Store).to receive(:mock_id=).and_call_original
    allow(Mockit::Store).to receive(:write).and_call_original

    env = { "HTTP_X_MOCK_ID" => "mock-header-id" }
    status, _headers, _body = middleware.call(env)
    expect(Mockit::Store).to have_received(:mock_id=).with("mock-header-id")
    expect(status).to eq(200)
  end
end
