# frozen_string_literal: true

require "action_controller/railtie"

module Mockit
  # Rails controller handling setting and reading mock overrides for a service
  class MocksController < ActionController::API
    # Create or update overrides for a service under the current or provided mock id.
    #
    # Expects `service` and `overrides` params.
    #
    # POST /mockit/mocks
    def create
      service = params.require(:service)
      overrides = params.require(:overrides).permit!

      Mockit::Store.write(service:, overrides: overrides.to_h)
      render json: { status: "ok" }
    end

    # Delete overrides for a `service`. Also deletes associated mapping when a mock id
    # is provided either via params or from the RequestStore.
    #
    # DELETE /mockit/mocks
    def destroy
      service = params.require(:service)

      # delete service overrides
      Mockit::Store.delete(service: service)

      # also delete mapping if mock_id provided or present in current request
      mock_id = Mockit::Store.current_mock_id
      Mockit::Store.delete_mapping(mock_id: mock_id) if mock_id

      render json: { status: "ok" }
    end

    # DELETE /mocks/teardown
    # Delete all stored mocks and mappings for the current request's mock id.
    # Intended for teardown use in tests; it's a no-op if no mock id is present.
    def destroy_all
      Mockit::Store.delete_all
      render json: { status: "ok" }
    end

    # POST /map_request
    # Create a mapping rule that associates incoming requests matching the `match`
    # criteria with a `mock_id`. Expects a `match` param (hash). `mock_id` may be
    # provided explicitly or inferred from the RequestStore. `ttl` may be used to
    # set expiration for the mapping.
    def create_mapping
      match = params.require(:match).permit!.to_h
      mock_id = Mockit::Store.current_mock_id
      ttl = params[:ttl] || 600

      unless mock_id
        render json: { error: "mock_id missing" }, status: :bad_request
        return
      end

      Mockit::Store.write_mapping(match: match, mock_id: mock_id, ttl: ttl.to_i)
      render json: { status: "ok" }
    end

    # GET /mockit/mocks
    # Return the stored overrides for a given `service` under the current mock id.
    def show
      service = params.require(:service)

      overrides = Mockit::Store.read(service: service)
      if overrides
        render json: overrides
      else
        render json: { error: "Not Found" }, status: :not_found
      end
    end
  end
end
