# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mockit::MocksController", type: :request do
  let(:service) { "my/module/test/service" }
  describe "POST /mockit/mocks" do
    let(:valid_params) do
      {
        service: service,
        overrides: { data: "mocked last_response", status: "200" }
      }
    end

    it "stores the mock last_response and returns status ok" do
      expect(Mockit::Store).to receive(:write).with(
        service: valid_params[:service],
        overrides: valid_params[:overrides]
      )

      post "/mockit/mocks", params: valid_params

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "ok")
    end
  end

  describe "GET /mockit/mocks/:service" do
    let(:mock_response) { { "data" => "mocked last_response", "status" => 200 } }

    context "when mock exists" do
      before do
        allow(Mockit::Store).to receive(:read)
          .with(service: service)
          .and_return(mock_response)
      end

      it "returns the mock last_response" do
        get "/mockit/mocks/#{service}"

        expect(response).to have_http_status(:ok)
        expect(JSON.parse(response.body)).to eq(mock_response)
      end
    end

    context "when mock does not exist" do
      before do
        allow(Mockit::Store).to receive(:read)
          .with(service: service)
          .and_return(nil)
      end

      it "returns not found status" do
        get "/mockit/mocks/#{service}"

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq("error" => "Not Found")
      end
    end
  end

  describe "DELETE /mockit/mocks/:service" do
    context "when mock exists" do
      before do
        expect(Mockit::Store).to receive(:delete).with(service: service).and_return(true)
      end

      it "returns ok when deleted" do
        delete "/mockit/mocks/#{service}"

        expect(response).to have_http_status(:ok)
      end
    end

    context "when mock does not exist" do
      before do
        expect(Mockit::Store).to receive(:delete).with(service: "something").and_return(false)
      end

      it "returns not found when missing" do
        delete "/mockit/mocks/something"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
