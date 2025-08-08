# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::FaradayMiddleware do
  it "adds X-Mock-Id header when mock_id is present" do
    RequestStore.store[:mock_id] = "faraday-123"

    captured_env = nil
    app = ->(env) { captured_env = env; [200, {}, "ok"] }
    middleware = described_class.new(app)

    # Build a minimal env with request headers
    env = Struct.new(:request_headers).new({})

    middleware.call(env)

    expect(captured_env.request_headers["X-Mock-Id"]).to eq("faraday-123")
  end

  it "does not add header when mock_id is absent" do
    RequestStore.clear!

    captured_env = nil
    app = ->(env) { captured_env = env; [200, {}, "ok"] }
    middleware = described_class.new(app)

    env = Struct.new(:request_headers).new({})

    middleware.call(env)

    expect(captured_env.request_headers["X-Mock-Id"]).to be_nil
  end
end

RSpec.describe "Mockit::FaradayMiddleware registration" do
  it "registers with Faraday when available" do
    # Stub a minimal Faraday API
    stubbed_middleware = Class.new do
      def self.register_middleware(**opts)
        @registered ||= {}
        @registered.merge!(opts)
      end

      def self.registered
        @registered || {}
      end
    end
    stubbed_faraday = Module.new
    stubbed_faraday.const_set(:Middleware, stubbed_middleware)

    Object.const_set(:Faraday, stubbed_faraday)
    begin
      # Call registration helper explicitly
      Mockit::FaradayMiddleware.register_with_faraday
      expect(stubbed_middleware.registered.keys).to include(:mockit_header)
    ensure
      Object.send(:remove_const, :Faraday)
    end
  end
end


