# frozen_string_literal: true

require "action_controller/railtie"
require "mockit/controllers/concerns/requires_session_support"

module Mockit
  # Server-rendered scenario-picker UI over Store: browse and edit the service
  # overrides currently stored for a mock id. Implements no auth of its own --
  # see README "Scenario-picker UI" for the reasoning and how a host app can
  # restrict access to the mount point.
  #
  # Named `Scenarios`, not `Ui`: a host app that declares `inflect.acronym "UI"`
  # (some do) would make Rails look up `Mockit::UIController` instead of
  # `Mockit::UiController` for a route mapped to `"ui#..."`, breaking resolution.
  # The `/ui` URL path is unaffected -- only the route's `to:` keyword changed.
  class ScenariosController < ActionController::Base
    include Mockit::Engine.routes.url_helpers
    include Mockit::RequiresSessionSupport

    helper Mockit::Engine.routes.url_helpers
    protect_from_forgery with: :exception
    layout "mockit_ui"

    # GET /ui and GET /ui/:mock_id
    # Both routes hit this action -- :mock_id is optional. When absent, falls
    # back to Mockit.default_mock_id (see README "Default mock id"); when
    # neither is present, renders the mock-id picker alone with no services
    # table (there's nothing to look up yet). Never redirects on its own --
    # the picker form (same one shown here or on any mock's page) is a plain
    # GET that re-renders this same action with a mock_id query param.
    def show
      mock_id = params[:mock_id].presence || Mockit.default_mock_id
      # `:mock_id` is a single path segment (see routes.rb) and can't carry a
      # literal "/" -- reject rather than build service-action links that
      # would 404. Ids created via the JSON API have no such restriction, so
      # this only affects browsing one of those ids through the UI.
      if mock_id&.include?("/")
        flash.now[:alert] = "Mock IDs containing \"/\" aren't supported by this UI -- use the JSON API for that id."
        mock_id = nil
      end

      @mock_id = mock_id
      @known_mock_ids = Mockit::KnownMockIds.all.reject { |id| id.include?("/") }
      @services = @mock_id ? services_for(@mock_id) : []
    end

    # POST /ui/:mock_id/services
    # Create or update the override for a service under this mock id.
    def apply_service
      mock_id = params[:mock_id]
      service = params[:service].presence
      overrides = parse_overrides(params[:overrides_json])

      if service && overrides
        Mockit::Store.mock_id = mock_id
        Mockit::Store.write(service: service, overrides: overrides)
      else
        flash[:alert] = "Service name and valid JSON overrides are required"
      end

      redirect_to ui_mock_path(mock_id)
    end

    # POST /ui/:mock_id/services/scenario
    # Apply a named, pre-registered scenario (see Mockit.register_scenario) for a service.
    def apply_scenario
      mock_id = params[:mock_id]
      service = params[:service].presence
      scenario_name = params[:scenario_name].presence

      if service && scenario_name
        apply_named_scenario(mock_id, service, scenario_name)
      else
        flash[:alert] = "Service and scenario are required"
      end

      redirect_to ui_mock_path(mock_id)
    end

    # POST /ui/:mock_id/services/reset
    # Re-apply a service's default ("happy path") scenario, if one is registered.
    def reset_service
      mock_id = params[:mock_id]
      service = params[:service].presence
      default_name = service && Mockit.default_scenario_name_for(service)

      if default_name
        apply_named_scenario(mock_id, service, default_name)
      else
        flash[:alert] = "No happy-path scenario registered for #{service}"
      end

      redirect_to ui_mock_path(mock_id)
    end

    # POST /ui/:mock_id/services/delete
    # Remove a single service override for this mock id.
    def destroy_service
      mock_id = params[:mock_id]
      service = params[:service].presence

      if service
        Mockit::Store.mock_id = mock_id
        Mockit::Store.delete(service: service)
      end

      redirect_to ui_mock_path(mock_id)
    end

    # POST /ui/:mock_id/teardown
    # Remove every service override and mapping for this mock id.
    def destroy_all_services
      mock_id = params[:mock_id]

      Mockit::Store.mock_id = mock_id
      Mockit::Store.delete_all

      redirect_to ui_mock_path(mock_id)
    end

    private

    def apply_named_scenario(mock_id, service, scenario_name)
      overrides = Mockit.resolve_scenario(service: service, name: scenario_name)
      Mockit::Store.mock_id = mock_id
      Mockit::Store.write(service: service, overrides: overrides)
    rescue StandardError => e
      flash[:alert] = e.message
    end

    # Lists every service that either already has an override for this mock
    # id, or has at least one registered scenario (Mockit.known_services) --
    # so the picker can offer "apply happy_path" for a service before it's
    # ever been mocked, not just after.
    def services_for(mock_id)
      Mockit::Store.mock_id = mock_id
      names = (Mockit::Store.read_services_for_mock(mock_id) + Mockit.known_services).uniq.sort

      names.map do |service|
        {
          name: service,
          overrides: Mockit::Store.read(service: service),
          scenario_names: Mockit.scenarios_for(service).keys,
          default_scenario_name: Mockit.default_scenario_name_for(service)
        }
      end
    end

    def parse_overrides(json)
      parsed = JSON.parse(json.to_s)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
  end
end
