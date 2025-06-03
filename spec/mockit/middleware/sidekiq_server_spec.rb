# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware::SidekiqServer do
  it "sets mock_id in RequestStore from job payload" do
    job = { "mock_id" => "job-mock-id" }
    middleware = described_class.new

    middleware.call("TestWorker", job, "default") do
      expect(Mockit::Store.current_mock_id).to eq("job-mock-id")
    end
  end
end
