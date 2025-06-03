# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "Mockit E2E", type: :request do
  let(:mockit_header) { { "HTTP_X_MOCKIT_ID" => "abc123" } }

  it "creates and fetches a mock last_response via the mockit engine" do
    service = "payment_service"
    overrides = { message: "success", code: 200 }

    # POST /mockit/mocks to create a mock
    post "/mockit/mocks",
         params: {
           service: service,
           overrides: overrides
         },
         headers: mockit_header,
         as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq("status" => "ok")

    # GET /mockit/mocks to retrieve the mock last_response
    get "/mockit/mocks", params: { service: service }, headers: mockit_header, as: :json

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)).to eq(overrides.stringify_keys)
  end

  it "returns 404 for unknown mock" do
    get "/mockit/mocks", params: { service: "unknown_service" }, headers: mockit_header

    expect(response).to have_http_status(:not_found)
    expect(JSON.parse(response.body)).to eq("error" => "Not Found")
  end
end
