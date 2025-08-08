# frozen_string_literal: true

module Mockit
  # Faraday middleware responsible for passing mock header down the call chain
  # Note: This middleware does not require Faraday to be installed to be loaded
  # or tested. If Faraday is available, it can be registered via the Builder API.
  class FaradayMiddleware
    def self.register_with_faraday
      return unless defined?(Faraday)
      Faraday::Middleware.register_middleware mockit_header: -> { Mockit::FaradayMiddleware }
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      mock_id = Mockit::Store.current_mock_id
      env.request_headers["X-Mock-Id"] = mock_id if mock_id
      @app.call(env)
    end
  end
end

# Register with Faraday when it is available
Mockit::FaradayMiddleware.register_with_faraday
