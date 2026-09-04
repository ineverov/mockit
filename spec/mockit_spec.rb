# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit do
  after { described_class.instance_variable_set(:@scenarios, nil) }

  describe ".register_scenario / .scenarios_for" do
    it "registers a scenario under a service, keyed by name" do
      described_class.register_scenario(service: "external_service", name: "happy_path",
                                        overrides: { "status" => "ok" })

      expect(described_class.scenarios_for("external_service")).to eq(
        "happy_path" => { overrides: { "status" => "ok" }, default: false }
      )
    end

    it "returns an empty hash for a service with no registered scenarios" do
      expect(described_class.scenarios_for("clients/unknown_api")).to eq({})
    end

    it "accepts a Symbol service/name and stores it as a String" do
      described_class.register_scenario(service: :external_service, name: :happy_path, overrides: {})

      expect(described_class.scenarios_for("external_service").keys).to eq(["happy_path"])
    end
  end

  describe ".default_scenario_name_for" do
    it "returns the name of the scenario registered with default: true" do
      described_class.register_scenario(service: "external_service", name: "declined", overrides: {})
      described_class.register_scenario(service: "external_service", name: "happy_path", overrides: {}, default: true)

      expect(described_class.default_scenario_name_for("external_service")).to eq("happy_path")
    end

    it "returns nil when no scenario for the service is marked default" do
      described_class.register_scenario(service: "external_service", name: "happy_path", overrides: {})

      expect(described_class.default_scenario_name_for("external_service")).to be_nil
    end

    it "returns nil when the service has no registered scenarios at all" do
      expect(described_class.default_scenario_name_for("clients/unknown_api")).to be_nil
    end
  end

  describe ".known_services" do
    it "lists every service with at least one registered scenario" do
      described_class.register_scenario(service: "external_service", name: "happy_path", overrides: {})
      described_class.register_scenario(service: "other_service", name: "happy_path", overrides: {})

      expect(described_class.known_services).to contain_exactly("external_service", "other_service")
    end

    it "is empty when nothing has been registered" do
      expect(described_class.known_services).to eq([])
    end
  end

  describe ".resolve_scenario" do
    it "returns a Hash override as-is" do
      described_class.register_scenario(service: "external_service", name: "happy_path",
                                        overrides: { "status" => "ok" })

      expect(described_class.resolve_scenario(service: "external_service", name: "happy_path")).to eq("status" => "ok")
    end

    it "calls a callable override and returns its result, fresh each time" do
      counter = 0
      described_class.register_scenario(
        service: "external_service", name: "happy_path", overrides: lambda {
          counter += 1
          { "call" => counter }
        }
      )

      expect(described_class.resolve_scenario(service: "external_service", name: "happy_path")).to eq("call" => 1)
      expect(described_class.resolve_scenario(service: "external_service", name: "happy_path")).to eq("call" => 2)
    end

    it "raises ArgumentError for an unregistered service" do
      expect do
        described_class.resolve_scenario(service: "clients/unknown_api", name: "happy_path")
      end.to raise_error(ArgumentError, %r{No scenario named happy_path registered for service clients/unknown_api})
    end

    it "raises ArgumentError for an unregistered scenario name on a known service" do
      described_class.register_scenario(service: "external_service", name: "happy_path", overrides: {})

      expect do
        described_class.resolve_scenario(service: "external_service", name: "declined")
      end.to raise_error(ArgumentError, /No scenario named declined registered for service external_service/)
    end
  end
end
