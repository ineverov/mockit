# frozen_string_literal: true

require "faraday"

Faraday::Middleware.register_middleware mockit_header: -> { Mockit::FaradayMiddleware }

module Mockit
  # Faraday middleware responsible for passing mock header down the call chain
  class FaradayMiddleware < Faraday::Middleware
    def call(env)
      mock_id = Mockit::Store.current_mock_id
      env.request_headers["X-Mock-Id"] = mock_id if mock_id
      @app.call(env)
    end
  end
end
