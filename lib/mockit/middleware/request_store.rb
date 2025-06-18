# frozen_string_literal: true

require "request_store"

module Mockit
  module Middleware
    # Middleware to read header from the request and set it for future use
    class RequestStore
      def initialize(app)
        @app = app
      end

      def call(env)
        ::RequestStore.begin!
        mock_id = env["HTTP_X_MOCK_ID"]
        if mock_id
          Mockit.logger.info "Setting mock_id for request to #{mock_id}"
          Mockit::Store.mock_id = mock_id
        end
        @app.call(env)
      ensure
        ::RequestStore.end!
        ::RequestStore.clear!
      end
    end
  end
end
