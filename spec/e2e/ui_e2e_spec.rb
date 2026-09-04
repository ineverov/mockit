# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Mockit scenario-picker UI", type: :request do
  let(:mock_id) { "ui-test-#{SecureRandom.hex(4)}" }

  after do
    RequestStore.store[:mockit_id] = mock_id
    Mockit::Store.delete_all
    RequestStore.store.clear
  end

  describe "GET /mockit/ui" do
    after { Mockit.default_mock_id = nil }

    it "renders the mock id entry form when no mock id is given and no default is set" do
      get "/mockit/ui"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Select a mock ID")
      expect(response.body).not_to include("Scenarios for")
    end

    it "offers known mock ids as pickable suggestions when none is chosen yet" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      get "/mockit/ui"

      expect(response.body).to include(%(<option value="#{mock_id}">))
    end

    it "renders that mock's page directly (no redirect) when a mock id is submitted" do
      get "/mockit/ui", params: { mock_id: mock_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Scenarios for")
      expect(response.body).to include(mock_id)
    end

    it "pre-fills the entry form with Mockit.default_mock_id, without redirecting past it" do
      Mockit.default_mock_id = "dev-default"

      get "/mockit/ui"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(%(value="dev-default"))
    end

    it "still prefers an explicit mock id over the default" do
      Mockit.default_mock_id = "dev-default"

      get "/mockit/ui", params: { mock_id: mock_id }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(mock_id)
      expect(response.body).not_to include(%(value="dev-default"))
    end
  end

  describe "GET /mockit/ui/:mock_id" do
    it "shows no overrides when none are set" do
      get "/mockit/ui/#{mock_id}"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("No overrides set for this mock ID yet.")
    end

    it "offers a way to switch to a different mock id without leaving the page" do
      get "/mockit/ui/#{mock_id}"

      expect(response.body).to include("Switch mock ID")
      expect(response.body).to include(%(value="#{mock_id}"))
    end

    it "lists other mock ids with live overrides as recently-used links" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      other_id = "ui-test-other"
      RequestStore.store[:mockit_id] = other_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      get "/mockit/ui/#{mock_id}"

      expect(response.body).to include("Recently used")
      expect(response.body).to include(%(href="/mockit/ui/#{other_id}"))

      RequestStore.store[:mockit_id] = other_id
      Mockit::Store.delete_all
      RequestStore.store.clear
    end

    it "lists an existing override" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      get "/mockit/ui/#{mock_id}"

      expect(response.body).to include("external_service")
      expect(response.body).to include("ok")
    end

    context "with a registered scenario" do
      after { Mockit.instance_variable_set(:@scenarios, nil) }

      it "lists a known service with no active override as not mocked, with a scenario picker" do
        Mockit.register_scenario(service: "external_service", name: "happy_path", overrides: {}, default: true)

        get "/mockit/ui/#{mock_id}"

        expect(response.body).to include("external_service")
        expect(response.body).to include("Not mocked")
        expect(response.body).to include("happy_path")
        expect(response.body).to include("Reset to happy path")
      end

      it "offers the scenario picker and reset for an already-mocked service" do
        Mockit.register_scenario(service: "external_service", name: "happy_path", overrides: {}, default: true)
        RequestStore.store[:mockit_id] = mock_id
        Mockit::Store.write(service: "external_service", overrides: { "status" => "declined" })
        RequestStore.store.clear

        get "/mockit/ui/#{mock_id}"

        expect(response.body).to include("Advanced: edit JSON directly")
        expect(response.body).to include("Delete (use real connection)")
        expect(response.body).to include("Reset to happy path")
      end

      it "shows 'No scenarios registered' for an active override with no matching scenarios" do
        RequestStore.store[:mockit_id] = mock_id
        Mockit::Store.write(service: "clients/unregistered_api", overrides: { "status" => "ok" })
        RequestStore.store.clear

        get "/mockit/ui/#{mock_id}"

        expect(response.body).to include("No scenarios registered")
      end
    end
  end

  describe "POST /mockit/ui/:mock_id/services" do
    it "creates a new override and redirects back to the mock page" do
      post "/mockit/ui/#{mock_id}/services",
           params: { service: "external_service", overrides_json: '{"status":"ok"}' }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to eq("status" => "ok")
      RequestStore.store.clear
    end

    it "updates an existing override" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      post "/mockit/ui/#{mock_id}/services",
           params: { service: "external_service", overrides_json: '{"status":"declined"}' }

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to eq("status" => "declined")
      RequestStore.store.clear
    end

    it "sets a flash alert and does not write when service is blank" do
      post "/mockit/ui/#{mock_id}/services", params: { service: "", overrides_json: "{}" }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")
      follow_redirect!
      expect(response.body).to include("Service name and valid JSON overrides are required")
    end

    it "sets a flash alert and does not write when overrides is invalid JSON" do
      post "/mockit/ui/#{mock_id}/services", params: { service: "external_service", overrides_json: "not json" }

      follow_redirect!
      expect(response.body).to include("Service name and valid JSON overrides are required")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to be_nil
      RequestStore.store.clear
    end

    it "rejects overrides that are valid JSON but not an object" do
      post "/mockit/ui/#{mock_id}/services", params: { service: "external_service", overrides_json: "[1,2,3]" }

      follow_redirect!
      expect(response.body).to include("Service name and valid JSON overrides are required")
    end
  end

  describe "POST /mockit/ui/:mock_id/services/scenario" do
    after { Mockit.instance_variable_set(:@scenarios, nil) }

    it "applies a registered scenario and redirects back to the mock page" do
      Mockit.register_scenario(service: "external_service", name: "happy_path", overrides: { "status" => "ok" })

      post "/mockit/ui/#{mock_id}/services/scenario",
           params: { service: "external_service", scenario_name: "happy_path" }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to eq("status" => "ok")
      RequestStore.store.clear
    end

    it "sets a flash alert and does not write when the scenario name is unregistered" do
      Mockit.register_scenario(service: "external_service", name: "happy_path", overrides: { "status" => "ok" })

      post "/mockit/ui/#{mock_id}/services/scenario",
           params: { service: "external_service", scenario_name: "declined" }

      follow_redirect!
      expect(response.body).to include("No scenario named declined registered for service external_service")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to be_nil
      RequestStore.store.clear
    end

    it "sets a flash alert when service or scenario_name is blank" do
      post "/mockit/ui/#{mock_id}/services/scenario", params: { service: "", scenario_name: "" }

      follow_redirect!
      expect(response.body).to include("Service and scenario are required")
    end
  end

  describe "POST /mockit/ui/:mock_id/services/reset" do
    after { Mockit.instance_variable_set(:@scenarios, nil) }

    it "re-applies the service's default scenario" do
      Mockit.register_scenario(service: "external_service", name: "declined", overrides: { "status" => "declined" })
      Mockit.register_scenario(
        service: "external_service", name: "happy_path", overrides: { "status" => "ok" }, default: true
      )
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "declined" })
      RequestStore.store.clear

      post "/mockit/ui/#{mock_id}/services/reset", params: { service: "external_service" }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to eq("status" => "ok")
      RequestStore.store.clear
    end

    it "sets a flash alert and does not change stored state when no default scenario is registered" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "declined" })
      RequestStore.store.clear

      post "/mockit/ui/#{mock_id}/services/reset", params: { service: "external_service" }

      follow_redirect!
      expect(response.body).to include("No happy-path scenario registered for external_service")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to eq("status" => "declined")
      RequestStore.store.clear
    end
  end

  describe "POST /mockit/ui/:mock_id/services/delete" do
    it "removes a single service override" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      RequestStore.store.clear

      post "/mockit/ui/#{mock_id}/services/delete", params: { service: "external_service" }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read(service: "external_service")).to be_nil
      RequestStore.store.clear
    end

    it "is a no-op when service is blank" do
      post "/mockit/ui/#{mock_id}/services/delete", params: { service: "" }

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")
    end
  end

  describe "POST /mockit/ui/:mock_id/teardown" do
    it "removes every override for the mock id" do
      RequestStore.store[:mockit_id] = mock_id
      Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
      Mockit::Store.write(service: "other_service", overrides: { "status" => "sent" })
      RequestStore.store.clear

      post "/mockit/ui/#{mock_id}/teardown"

      expect(response).to redirect_to("/mockit/ui/#{mock_id}")

      RequestStore.store[:mockit_id] = mock_id
      expect(Mockit::Store.read_services_for_mock(mock_id)).to eq([])
      RequestStore.store.clear
    end
  end
end
