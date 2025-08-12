# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "MapRequest E2E", type: :request do
  it "creates a mapping with explicit mock_id" do
    match = { "path" => "^/ttl$" }

    RequestStore.store[:mockit_id] = "m-explicit"

    post "/mockit/map_request",
         params: { match: match, ttl: 10 },
         as: :json

    expect(response).to have_http_status(:ok)

    mappings = Mockit::Store.read_mappings
    expect(mappings.map { |m| m["id"] }).to include("m-explicit")
  end

  it "creates a mapping using RequestStore mock id" do
    RequestStore.store[:mockit_id] = "m-from-rs"
    match = { "path" => "^/rs$" }

    post "/mockit/map_request",
         params: { match: match },
         as: :json

    expect(response).to have_http_status(:ok)

    mappings = Mockit::Store.read_mappings
    expect(mappings.map { |m| m["id"] }).to include("m-from-rs")

    RequestStore.store.clear
  end

  it "returns bad request when match missing" do
    post "/mockit/map_request", params: { mock_id: "x" }
    expect(response).to have_http_status(:bad_request)
  end
end
