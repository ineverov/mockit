require "request_store"

module Mockit
  module Middleware
    class RequestStore
      def initialize(app)
        @app = app
      end

      def call(env)
        ::RequestStore.begin!
        mock_id = env["HTTP_X_MOCK_ID"]
        Rails.logger.info "Setting mock_id for request to #{env["HTTP_X_MOCK_ID"]}. ENV= #{env}"
        Mockit::Store.mock_id = mock_id if mock_id
        @app.call(env)
      ensure
        ::RequestStore.end!
        ::RequestStore.clear!
      end
    end
  end
end
