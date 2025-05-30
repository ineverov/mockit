require "spec_helper"

RSpec.describe Mockit::Middleware::SidekiqClient do
  it "adds mock_id to job if present" do
    RequestStore.store[:mock_id] = "sidekiq-mock-id"
    job = {}

    described_class.new.call("TestWorker", job, "default", nil) {}
    expect(job["mock_id"]).to eq("sidekiq-mock-id")
  end
end

