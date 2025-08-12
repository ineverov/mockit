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

  describe "GET /mockit/mocks" do
    let(:service) { "my_service" }
    let(:mock_response) { { "data" => "mocked last_response", "status" => 200 } }

    context "when mock exists" do
      before do
        allow(Mockit::Store).to receive(:read)
          .with(service: service)
          .and_return(mock_response)
      end

      it "returns the mock last_response" do
        get "/mockit/mocks", params: { service: service }

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
        get "/mockit/mocks", params: { service: service }

        expect(response).to have_http_status(:not_found)
        expect(JSON.parse(response.body)).to eq("error" => "Not Found")
      end
    end
  end

  describe "DELETE /mockit/mocks" do
    it "deletes the mock and returns ok" do
      expect(Mockit::Store).to receive(:delete).with(service: service)

      delete "/mockit/mocks", params: { service: service }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)).to eq("status" => "ok")
    end

    it "deletes mapping when mock_id param provided" do
      RequestStore.store[:mockit_id] = "map-1"
      expect(Mockit::Store).to receive(:delete).with(service: service)
      expect(Mockit::Store).to receive(:delete_mapping).with(mock_id: "map-1")

      delete "/mockit/mocks", params: { service: service }

      expect(response).to have_http_status(:ok)
    end

    it "deletes mapping when mock_id is present in RequestStore" do
      RequestStore.store[:mockit_id] = "rs-1"
      expect(Mockit::Store).to receive(:delete).with(service: service)
      expect(Mockit::Store).to receive(:delete_mapping).with(mock_id: "rs-1")

      delete "/mockit/mocks", params: { service: service }

      expect(response).to have_http_status(:ok)
    end
  end

  describe "DELETE /mockit/mocks/teardown" do
    after do
      Mockit.storage.delete("mockit:mappings")
    end

    # rubocop:disable Metrics/BlockLength
    it "deletes all mocks and mappings" do
      # set a mock under mock_id m-abc and another under m-other
      # create first mock with RequestStore set
      RequestStore.store[:mockit_id] = "m-abc"
      post "/mockit/mocks", params: { service: "svc", overrides: { foo: "bar" } }
      RequestStore.store.clear

      # create second mock under a different id
      RequestStore.store[:mockit_id] = "m-other"
      post "/mockit/mocks", params: { service: "svc2", overrides: { foo: "baz" } }
      RequestStore.store.clear

      # add mappings for both
      post "/mockit/map_request", params: { match: { path: "/test" } }
      post "/mockit/map_request", params: { match: { path: "/other" } }

      # ensure they exist
      RequestStore.store[:mockit_id] = "m-abc"
      get "/mockit/mocks", params: { service: "svc" }
      expect(response).to have_http_status(:ok)
      RequestStore.store.clear

      RequestStore.store[:mockit_id] = "m-other"
      get "/mockit/mocks", params: { service: "svc2" }
      expect(response).to have_http_status(:ok)
      RequestStore.store.clear

      # now delete only m-abc (controller uses RequestStore, not params)
      RequestStore.store[:mockit_id] = "m-abc"
      delete "/mockit/mocks/teardown"
      expect(response).to have_http_status(:ok)
      RequestStore.store.clear

      # verify m-abc mock gone, but m-other remains
      RequestStore.store[:mockit_id] = "m-abc"
      get "/mockit/mocks", params: { service: "svc" }
      expect(response).to have_http_status(:not_found)
      RequestStore.store.clear

      RequestStore.store[:mockit_id] = "m-other"
      get "/mockit/mocks", params: { service: "svc2" }
      expect(response).to have_http_status(:ok)
    end
    # rubocop:enable Metrics/BlockLength
  end

  describe "POST /mockit/map_request additional cases" do
    it "passes ttl param to write_mapping" do
      RequestStore.store[:mockit_id] = "abc"
      match = { "path" => "^/ttl$" }
      expect(Mockit::Store).to receive(:write_mapping).with(match: match, mock_id: "abc", ttl: 10)

      post "/mockit/map_request", params: { match: match, ttl: 10 }
      expect(response).to have_http_status(:ok)
    end

    it "returns bad request when match param missing" do
      post "/mockit/map_request", params: { mock_id: "abc" }
      expect(response).to have_http_status(:bad_request)
    end

    it "returns bad request when mock_id is not provided anywhere" do
      # ensure RequestStore has no mock_id
      RequestStore.store.clear

      post "/mockit/map_request", params: { match: { "path" => "/x" } }
      expect(response).to have_http_status(:bad_request)
    end
  end
end
