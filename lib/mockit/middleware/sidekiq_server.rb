module Mockit
  module Middleware
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
