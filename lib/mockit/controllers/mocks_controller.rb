require "action_controller/railtie"

module Mockit
  class MocksController < ActionController::API
    def create
      service = params.require(:service)
      overrides = params.require(:overrides).permit!

      Mockit::Store.write(service:, overrides: overrides.to_h)
      render json: { status: "ok" }
    end

    def show
      service  = params.require(:service)

      overrides = Mockit::Store.read(service: service)
      if overrides
        render json: overrides
      else
        render json: { error: "Not Found" }, status: :not_found
      end
    end
  end
end
