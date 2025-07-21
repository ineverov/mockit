# frozen_string_literal: true

require "action_controller/railtie"

module Mockit
  # Rails controller handling setting and reading mock overrides for a service
  class MocksController < ActionController::API
    def create
      service = params.require(:service)
      overrides = params.require(:overrides).permit!

      Mockit::Store.write(service:, overrides: overrides.to_h)
      render json: { status: "ok" }
    end

    def show
      service = params.require(:service)

      overrides = Mockit::Store.read(service: service)
      if overrides
        render json: overrides
      else
        render json: { error: "Not Found" }, status: :not_found
      end
    end

    def destroy
      service = params.require(:service)

      deleted = Mockit::Store.delete(service: service)
      if deleted
        render json: { status: "ok" }
      else
        render json: { error: "Not Found" }, status: :not_found
      end
    end
  end
end
