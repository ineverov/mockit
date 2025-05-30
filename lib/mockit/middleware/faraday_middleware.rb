require 'faraday'

Faraday::Middleware.register_middleware mockit_header: -> { Mockit::FaradayMiddleware }

module Mockit
  class FaradayMiddleware < Faraday::Middleware
    def call(env)
      mock_id = Mockit::Store.current_mock_id
      env.request_headers["X-Mock-Id"] = mock_id if mock_id
      @app.call(env)
    end
  end
end
