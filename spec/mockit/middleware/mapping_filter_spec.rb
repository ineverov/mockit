# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware::MappingFilter do
  let(:captured) { {} }
  let(:app) do
    lambda { |env|
      captured[:mock_id] = Mockit::Store.current_mock_id
      [200, env, "app"]
    }
  end
  let(:middleware) { described_class.new(app) }

  it "sets mock_id when path matches mapping" do
    mapping = { "id" => "mapped-mock", "match" => { "path" => "^/loan/.*/details$" }, "created_at" => Time.now.to_i,
                "ttl" => 3600 }

    allow(Mockit::Store).to receive(:read_mappings).and_return([mapping])

    env = { "PATH_INFO" => "/loan/123/details" }
    status, _headers, _body = middleware.call(env)

    expect(captured[:mock_id]).to eq("mapped-mock")
    expect(status).to eq(200)
  end
end
