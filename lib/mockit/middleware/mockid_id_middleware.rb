# frozen_string_literal: true

require "request_store"

module Mockit
  module Middleware
    # Middleware to read `X-Mockit-Id` header from the request and set it in RequestStore
    class MockitIdMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        # Set the current request's mock id from `X-Mockit-Id` header (preferred),
        # falling back to legacy `X-Mock-Id` for older clients.
        ::RequestStore.begin!

        mock_id = extract_mock_id(env)

        if mock_id
          Mockit.logger.info "Setting mock_id for request to #{mock_id}"
          Mockit::Store.mock_id = mock_id
        end
        @app.call(env)
      ensure
        ::RequestStore.end!
        ::RequestStore.clear!
      end

      private

      def extract_mock_id(env)
        deprecation_check(env)
        env["HTTP_X_MOCKIT_ID"] || env["HTTP_X_MOCK_ID"]
      end

      def deprecation_check(env)
        return unless env["HTTP_X_MOCK_ID"]
        return if env["HTTP_X_MOCKIT_ID"]

        Mockit.logger.warn "Mockit Deprecation: Switch to using X-Mockit-Id instead of X-Mock-Id"
      end
    end
  end
end
