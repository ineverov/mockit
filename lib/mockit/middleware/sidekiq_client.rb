# frozen_string_literal: true

module Mockit
  module Middleware
    # Sidekiq middleware on client side to add mock_it parameter to the job
    class SidekiqClient
      def call(_worker_class, job, _queue, _redis_pool)
        # Inject current `mock_id` into Sidekiq job payload on client side.
        mock_id = Mockit::Store.current_mock_id
        if mock_id
          job["mockit_id"] = mock_id
          Mockit.logger.info "Mockit: Inject mockit_id=#{mock_id} for a job #{job}"
        end
        yield
      end
    end
  end
end
