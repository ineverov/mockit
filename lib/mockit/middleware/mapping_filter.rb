# frozen_string_literal: true

module Mockit
  module Middleware
    # Middleware to match incoming requests against stored mappings and set mock id
    class MappingFilter
      def initialize(app)
        # Initialize the middleware with the downstream Rack app.
        #
        # @param app [#call] Rack-compatible application
        @app = app
      end

      def call(env)
        # Process a Rack request env and attempt to map incoming requests
        # to a `mock_id` using stored mappings. If a mock id is already set
        # in the request store this middleware is a no-op. Any unexpected
        # errors during mapping are logged and skipped to avoid breaking the
        # whole middleware chain.
        #
        # @param env [Hash] Rack environment
        # @return [Array] Rack response triple
        ::RequestStore.begin!
        begin
          attempt_mapping(env)
          @app.call(env)
        ensure
          ::RequestStore.end!
          ::RequestStore.clear!
        end
      end

      private

      def attempt_mapping(env)
        return if Mockit::Store.current_mock_id

        begin
          if (mapping = find_matching_mapping(env))
            Mockit.logger.info "MappingFilter matched request -> setting mock #{mapping}"
            Mockit::Store.mock_id = mapping["id"]
          end
        rescue StandardError => e
          Mockit.logger.error "MappingFilter error, skipping mappings: #{e.class}: #{e.message}"
        end
      end

      def find_matching_mapping(env)
        Mockit::Store.read_mappings.each do |mapping|
          next if Mockit::Store.expired_mapping?(mapping)
          next unless Mockit::Middleware::MappingMatcher.match?(mapping, env)

          return mapping
        end

        nil
      end
    end
  end
end
