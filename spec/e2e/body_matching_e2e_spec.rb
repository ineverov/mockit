# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Body Matching E2E", type: :request do
  let(:mock_id) { "body-e2e-test" }
  let(:mockit_header) { { "HTTP_X_MOCKIT_ID" => mock_id } }

  after do
    delete "/mockit/mocks/teardown", headers: mockit_header, as: :json
    RequestStore.store.clear
  end

  def create_mapping(match)
    post "/mockit/map_request",
         params: { match: match, ttl: 60 },
         headers: mockit_header,
         as: :json
    expect(response).to have_http_status(:ok)
  end

  def probe(body)
    post "/probe", params: body, as: :json
    JSON.parse(response.body)["mock_id"]
  end

  describe "body regex matching" do
    it "activates mapping when raw body matches regex" do
      create_mapping("body" => "create")
      expect(probe({ action: "create", user_id: 42 })).to eq(mock_id)
    end

    it "does not activate mapping when raw body does not match" do
      create_mapping("body" => "^create$")
      expect(probe({ action: "create", user_id: 42 })).to be_nil
    end

    it "does not activate mapping when body is unrelated" do
      create_mapping("body" => "delete")
      expect(probe({ action: "create" })).to be_nil
    end
  end

  describe "body_json matching" do
    it "activates mapping when flat JSON key matches" do
      create_mapping("body_json" => { "action" => "create" })
      expect(probe({ action: "create", extra: "ignored" })).to eq(mock_id)
    end

    it "does not activate mapping when flat JSON value does not match" do
      create_mapping("body_json" => { "action" => "delete" })
      expect(probe({ action: "create" })).to be_nil
    end

    it "activates mapping when nested JSON structure matches" do
      create_mapping("body_json" => { "user" => { "role" => "admin" } })
      expect(probe({ user: { role: "admin", name: "Alice" } })).to eq(mock_id)
    end

    it "does not activate mapping when nested value does not match" do
      create_mapping("body_json" => { "user" => { "role" => "admin" } })
      expect(probe({ user: { role: "viewer" } })).to be_nil
    end

    it "activates mapping combining body_json with path" do
      create_mapping("path" => "^/probe$", "body_json" => { "action" => "create" })
      expect(probe({ action: "create" })).to eq(mock_id)
    end

    it "does not activate when path matches but body_json does not" do
      create_mapping("path" => "^/probe$", "body_json" => { "action" => "delete" })
      expect(probe({ action: "create" })).to be_nil
    end
  end
end
