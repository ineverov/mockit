# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware::SidekiqClient do
  it "adds mock_id to job if present" do
    RequestStore.store[:mockit_id] = "sidekiq-mock-id"
    job = {}

    described_class.new.call("TestWorker", job, "default", nil) {} # rubocop:disable Lint/EmptyBlock
    expect(job["mockit_id"]).to eq("sidekiq-mock-id")
  end
end
