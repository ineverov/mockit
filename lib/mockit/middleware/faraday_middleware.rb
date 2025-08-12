# frozen_string_literal: true

require "faraday"

Faraday::Middleware.register_middleware mockit_header: -> { Mockit::FaradayMiddleware }

module Mockit
  # Faraday middleware responsible for passing mock header down the call chain
  class FaradayMiddleware < Faraday::Middleware
    def call(env)
      mock_id = Mockit::Store.current_mock_id
      if mock_id
        env.request_headers["X-Mockit-Id"] = mock_id
        Mockit.logger.info "Mockit: Inject X-Mockit-Id header with value #{mock_id}"
      end
      @app.call(env)
    end
  end
end
