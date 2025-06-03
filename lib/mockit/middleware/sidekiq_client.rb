# frozen_string_literal: true

module Mockit
  module Middleware
    # Sidekiq middleware on client side to add mock_it parameter to the job
    class SidekiqClient
      def call(_worker_class, job, _queue, _redis_pool)
        job["mock_id"] = Mockit::Store.current_mock_id if Mockit::Store.current_mock_id
        yield
      end
    end
  end
end
