# frozen_string_literal: true

require "rails"

module Mockit
  # Rails railtie
  class Railtie < Rails::Railtie
    initializer "mockit.insert_middleware" do |app|
      app.middleware.insert_before 0, Mockit::Middleware::MockitIdMiddleware
      app.middleware.insert_after Mockit::Middleware::MockitIdMiddleware, Mockit::Middleware::MappingFilter
    end

    # After Rails initializes, configure Sidekiq middleware (if present)
    # and run registered post-initialize hooks.
    config.after_initialize do
      Mockit::Railtie.configure_sidekiq if defined?(Sidekiq)
      Mockit.run_post_initialize_hooks!
    end

    def self.configure_sidekiq
      Sidekiq.configure_client do |config|
        config.client_middleware { |chain| chain.add Mockit::Middleware::SidekiqClient }
      end

      Sidekiq.configure_server do |config|
        config.client_middleware { |chain| chain.add Mockit::Middleware::SidekiqClient }
        # Outermost, so middleware enqueuing after the job body (Sidekiq Pro batch callbacks) still sees the mock id.
        config.server_middleware { |chain| chain.prepend Mockit::Middleware::SidekiqServer }
      end
    end
  end
end
