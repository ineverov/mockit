# frozen_string_literal: true

module Mockit
  module Middleware
    # Sidekiq middleware extracting mock id from parameters and setting it for request
    class SidekiqServer
      def call(_worker, job, _queue)
        # If a Sidekiq job contains a `mock_id`, set it in RequestStore for the job execution.
        if job["mockit_id"]
          ::RequestStore.begin!
          Mockit.logger.info "Mockit: Set Mockit::Store.mock_id=#{job["mockit_id"]} for a job #{job}"
          Mockit::Store.mock_id = job["mockit_id"]
        end
        yield
      ensure
        ::RequestStore.end!
        ::RequestStore.clear!
      end
    end
  end
end
