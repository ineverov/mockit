# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware do
  describe Mockit::Middleware::MappingFilter do
    let(:captured) { {} }
    let(:app) do
      lambda { |env|
        captured[:mock_id] = Mockit::Store.current_mock_id
        [200, env, "app"]
      }
    end
    let(:middleware) { described_class.new(app) }

    it "does not override when existing mock_id present" do
      mapping = { "id" => "mapped-mock", "match" => { "path" => ".*" }, "created_at" => Time.now.to_i, "ttl" => 3600 }
      allow(Mockit::Store).to receive(:read_mappings).and_return([mapping])

      RequestStore.store[:mockit_id] = "already"
      env = { "PATH_INFO" => "/anything" }
      middleware.call(env)
      expect(captured[:mock_id]).to eq("already")
      RequestStore.store.clear
    end

    it "skips expired mappings" do
      expired = { "id" => "old", "match" => { "path" => ".*" }, "created_at" => Time.now.to_i - 3600, "ttl" => 1 }
      allow(Mockit::Store).to receive(:read_mappings).and_return([expired])

      env = { "PATH_INFO" => "/anything" }
      middleware.call(env)
      expect(captured[:mock_id]).to be_nil
    end

    it "logs and skips when read_mappings raises" do
      allow(Mockit::Store).to receive(:read_mappings).and_raise(StandardError.new("boom"))
      expect(Mockit.logger).to receive(:error).with(/MappingFilter error, skipping mappings/)

      env = { "PATH_INFO" => "/anything" }
      status, = middleware.call(env)
      expect(status).to eq(200)
      expect(captured[:mock_id]).to be_nil
    end
  end

  describe Mockit::Middleware::MockitIdMiddleware do
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
  end

  describe Mockit::Middleware::SidekiqClient do
    it "adds mock_id to job if present" do
      RequestStore.store[:mockit_id] = "sidekiq-mock-id"
      job = {}

      described_class.new.call("TestWorker", job, "default", nil) {} # rubocop:disable Lint/EmptyBlock
      expect(job["mockit_id"]).to eq("sidekiq-mock-id")
    end
  end

  describe Mockit::Middleware::SidekiqServer do
    it "sets mock_id in RequestStore from job payload" do
      job = { "mockit_id" => "job-mock-id" }
      middleware = described_class.new

      middleware.call("TestWorker", job, "default") do
        expect(Mockit::Store.current_mock_id).to eq("job-mock-id")
      end
    end
  end
end
