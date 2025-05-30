module Mockit
  module Middleware
    class SidekiqClient
      def call(_worker_class, job, _queue, _redis_pool)
        job["mock_id"] = Mockit::Store.current_mock_id if Mockit::Store.current_mock_id
        yield
      end
    end
  end
end
