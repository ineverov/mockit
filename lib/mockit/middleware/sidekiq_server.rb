# frozen_string_literal: true

module Mockit
  module Middleware
    # Sidekiq middleware extracting mock id from parameters and setting it for request
    class SidekiqServer
      def call(_worker, job, _queue)
        if job["mock_id"]
          ::RequestStore.begin!
          Mockit::Store.mock_id = job["mock_id"]
        end
        yield
      ensure
        ::RequestStore.end!
        ::RequestStore.clear!
      end
    end
  end
end
